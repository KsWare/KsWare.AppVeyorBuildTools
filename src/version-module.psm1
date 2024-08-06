function Read-AppVeyorSettings {
    Write-Verbose "Read-AppVeyorSettings"
    # Read Settings
    if($isPR -eq $false) {
        $response = Invoke-RestMethod -Method Get -Uri "$apiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings" -Headers $env:AppveyorApiRequestHeaders
        $env:AppveyorSettings = $response.settings        
    } else {
        # dummy settings
        $env:AppveyorSettings = @{versionFormat = $env:APPVEYOR_BUILD_VERSION}        
    }
}

# Extract version format
function Extract-VersionsFormat {  
    Write-Verbose "Extract-VersionsFormat"
    $currentVersion = $env:APPVEYOR_BUILD_VERSION
    $env:VersionSegmentCount = $($currentVersion.Split(".")).Count
    $env:buildVersion = $env:APPVEYOR_BUILD_VERSION -replace '\.[^.]*$$', ''
    $env:buildNumber = $env:APPVEYOR_BUILD_NUMBER
   	Write-Host "Current version: $env:buildVersion.* / $($currentVersionSegments.Count) parts"
}

# Get new version from file
function Get-VersionFromFile {
    Write-Verbose "Get-VersionFromFile"
    if($env:isPR -eq $true -or -not (Test-Path $env:VersionFile)) { return }
    
    Write-Host "Read new version from file"
    $versionPattern = "^(\s*\##?\s*v?)(?<version>\d+\.\d+\.\d+)"
    $fileContent = Get-Content -path "$env:VersionFile" -TotalCount 5
    
    foreach ($line in $fileContent) {
        if ($line -match $versionPattern) {
            $newVersion = $matches['version']
            Write-Verbose "New version found: '$newVersion' in line '$line'"
            break
        }
    }    	
    if(-not ($newVersion)) {
        Write-Verbose "$fileContent"
        Write-Error -Message "`nERROR: No valid version found!" -ErrorAction Stop
        Exit-AppveyorBuild
    }

    $newVersionSegments = $newVersion.Split(".")	
    if($newVersionSegments.Count+1 -ne $env:VersionSegmentCount ) {
        Write-Verbose "false: $($newVersionSegments.Count+1) -ne $env:VersionSegmentCount "
        $env:APPVEYOR_SKIP_FINALIZE_ON_EXIT="true"
        Write-Error -Message "`nERROR: Unsupported version format!" -ErrorAction Stop
        Exit-AppveyorBuild
    }
    Write-Verbose "true"

    Write-Host "New version: $newVersion.* / $($newVersionSegments.Count+1) parts"
    Write-Verbose "return $newVersion"
    return $newVersion    
}

function Test-NewVersionIsGreater {
    Write-Verbose "Test-NewVersionIsCreater $env:buildVersion $env:newBuildVersion"
    $currentVersionSegments = $env:buildVersion.Split(".")
    $newVersionSegments = $env:newBuildVersion.Split(".")

    for ($i = 0; $i -lt $currentVersionSegments.Length; $i++) {
        if ([int]$newVersionSegments[$i] -gt [int]$currentVersionSegments[$i]) { 
            Write-Verbose ":True"
            return $true 
        } 
        if ([int]$newVersionSegments[$i] -lt [int]$currentVersionSegments[$i]) { 
            throw "New version is smaller than current version." 
        }
    }
    Write-Verbose ":False"
    return $false
}

function Reset-BuildNumber {
    Write-Verbose "Reset-BuildNumber"
    if(-not $env:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
    if(-not $env:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}

    $env:buildNumber = 0
    $json = @{ nextBuildNumber = 1 } | ConvertTo-Json    
    Write-Host "Invoke 'Reset Build Nummer'"
    Invoke-RestMethod -Method Put "$env:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $env:AppveyorApiRequestHeaders
} 

function Update-AppVeyorSettings {
    Write-Verbose "Update-AppVeyorSettings"
    if(-not $env:AppVeyorSettings) {throw "env:AppVeyorSettings is empty."}
    if(-not $env:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
    if(-not $env:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}

    $env:AppVeyorSettings.versionFormat = "$env:buildVersion.{build})"
    Write-Host "Build version format: $($env:AppVeyorSettings.versionFormat)"
    $body = ConvertTo-Json -Depth 10 -InputObject $env:AppVeyorSettings
    $response = Invoke-RestMethod -Method Put -Uri "$env:AppVeyorApiUrl/projects" -Headers $env:AppVeyorApiRequestHeaders -Body $body
}

# Enhance build version with timestamp
function Update-VersionWithTimestamp {
    [CmdletBinding()]param ()
    
    if (-not $env:versionMeta) {
        $env:versionMeta = "+$(Get-Date -Format 'yyyyMMddHHmmss')" }
    Update-AppveyorBuild -Version "$ENV:APPVEYOR_BUILD_VERSION$env:versionSuffix$env:versionMeta"
    Write-Host "env:APPVEYOR_BUILD_VERSION: $ENV:APPVEYOR_BUILD_VERSION"
}

function Update-Version {
	[CmdletBinding()]param ()
    try {
	    Write-Host "START: Update-Version"
	    Write-Host "isPR: $env:isPR"

        if($env:isPR -eq $true) { 
            Extract-VersionsFormat
            Write-Host ("INFO: Pull Request detected. skip Update-Version.")
        }
        else {
	        Write-Host "env:VersionFile: $env:VersionFile"	
            Read-AppVeyorSettings	
	        Extract-VersionsFormat
            $env:newBuildVersion = Get-VersionFromFile
            if(-not $env:newBuildVersion) { return }    
            if(Test-NewVersionIsGreater) { Reset-BuildNumber }
            Write-Verbose "C"
            $env:buildVersion = $env:newBuildVersion
            Update-AppVeyorSettings
            Update-AppveyorBuild -Version "$env:buildVersion.$env:buildNumber$env:versionSuffix$env:versionMeta"
        }
	
        Write-Host "env:APPVEYOR_BUILD_VERSION: $env:APPVEYOR_BUILD_VERSION"
	    Write-Host "env:buildVersion: $env:buildVersion"
	    Write-Host "env:buildNumber: $env:buildNumber"
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        Write-Host "ERROR: in $($_.InvocationInfo.MyCommand)"
        Write-Host "ERROR: in $MyInvocation.ScriptName at $($_.InvocationInfo.ScriptLineNumber):$($_.InvocationInfo.OffsetInLine)"
        Write-Host "ERROR: $($_.Exception.StackTrace)"        
        if ($_.Exception.InnerException) {
            Write-Host "INNER EXCEPTION: $($_.Exception.InnerException.Message)"
            Write-Host "INNER EXCEPTION STACK TRACE: $($_.Exception.InnerException.StackTrace)"
        }
        exit 1
    } finalize {
        Write-Host "END: Update-Version"
    }
}

# Reset build number
function Reset-BuildNumber {
	[CmdletBinding()]param ()
    Write-Verbose "Reset-BuildNumber"
    if($env:isPR -eq $true) { return } # skip if this is a pull request
    $build = @{ nextBuildNumber = $env:APPVEYOR_BUILD_NUMBER }
    $json = $build | ConvertTo-Json    
    Invoke-RestMethod -Method Put "$env:AppveyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $env:AppveyorApiRequestHeaders
    Write-Host "Next build number: $env:APPVEYOR_BUILD_NUMBER"
}

Export-ModuleMember -Function Update-Version, Update-VersionWithTimestamp, Reset-BuildNumber
