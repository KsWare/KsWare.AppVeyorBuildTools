
# Init AppVeyor API request 
function Init-AppVeyorApiRequest {
    Write-Verbose "Init-AppVeyorApiRequest"
	$env:AppveyorApiUrl = 'https://ci.appveyor.com/api'
	$env:AppveyorApiRequestHeaders = @{
		"Authorization" = "Bearer $env:AppVeyorApiToken"
		"Content-type" = "application/json"
		"Accept" = "application/json"
	}
}

function Read-AppVeyorSettings {
    Write-Verbose "Read-AppVeyorSettings"
    # Read Settings
    if($isPR -eq $false) {
        $response = Invoke-RestMethod -Method Get -Uri "$apiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings" -Headers $appveyorApiRequestHeaders
        $env:AppveyorSettings = $response.settings        
    } else {
        # dummy settings
        $env:AppveyorSettings = @{versionFormat = $env:APPVEYOR_BUILD_VERSION}        
    }
}

# Extract version format
function Extract-VersionsFormat {  
    $currentVersion = $env:APPVEYOR_BUILD_VERSION
    $env:VersionSegmentCount = $($currentVersion.Split(".")).Count
    $env:buildVersion = $env:APPVEYOR_BUILD_VERSION -replace '\.[^.]*$$', ''
    $env:buildNumber = $env:APPVEYOR_BUILD_NUMBER
   	Write-Output "Current version: $env:buildVersion.* / $($currentVersionSegments.Count) parts"
}

# Get new version from file
function Get-VersionFromFile {
    Write-Verbose "Get-VersionFromFile"
    if($env:isPR -eq $true -or -not (Test-Path $env:VersionFile)) { return }
    
    Write-Output "Read new version from file"
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
    if($newVersionSegments.Count+1 -ne $env:VersionSegmentCount) {
        $env:APPVEYOR_SKIP_FINALIZE_ON_EXIT="true"
        Write-Error -Message "`nERROR: Unsupported version format!" -ErrorAction Stop
        Exit-AppveyorBuild
    }

    Write-Output "New version: $newVersion.* / $($newVersionSegments.Count+1) parts"	
    return $newVersion
}

function Test-NewVersionIsGreater {
    Write-Verbose "Test-NewVersionIsCreater"
    $currentVersionSegments = $env:buildVersion.Split(".")
    $newVersionSegments = $env:newBuildVersion.Split(".")

    for ($i = 0; $i -lt $currentVersionSegments.Length; $i++) {
        if ([int]$newVersionSegments[$i] -gt [int]$currentVersionSegments[$i]) { return $true } 
        if ([int]$newVersionSegments[$i] -lt [int]$currentVersionSegments[$i]) { throw "New version is smaller than current version." }
    }
    return $false
}

function Reset-BuildNumber {
    Write-Verbose "Reset-BuildNumber"
    if(-not $env:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
    if(-not $env:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}

    $env:buildNumber = 0
    $json = @{ nextBuildNumber = 1 } | ConvertTo-Json    
    Write-Output "Invoke 'Reset Build Nummer'"
    Invoke-RestMethod -Method Put "$env:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $env:AppveyorApiRequestHeaders
} 

function Update-AppVeyorSettings {
    if(-not $env:AppVeyorSettings) {throw "env:AppVeyorSettings is empty."}
    if(-not $env:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
    if(-not $env:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}

    $env:AppVeyorSettings.versionFormat = "$env:buildVersion.{build})"
    Write-Output "Build version format: $($env:AppVeyorSettings.versionFormat)"
    $body = ConvertTo-Json -Depth 10 -InputObject $settings
    $response = Invoke-RestMethod -Method Put -Uri "$env:AppVeyorApiUrl/projects" -Headers $env:AppVeyorApiRequestHeaders -Body $body
}

# Enhance build version with timestamp
function Update-VersionWithTimestamp {
    [CmdletBinding()]param ()
    
    if (-not $env:versionMeta) {
        $env:versionMeta = "+$(Get-Date -Format 'yyyyMMddHHmmss')" }
    Update-AppveyorBuild -Version "$ENV:APPVEYOR_BUILD_VERSION$env:versionSuffix$env:versionMeta"
    Write-Output "env:APPVEYOR_BUILD_VERSION: $ENV:APPVEYOR_BUILD_VERSION"
}

function Update-Version {
	[CmdletBinding()]param ()
    try {
	    Write-Output "START: Update-Version"
	    Write-Output "isPR: $env:isPR"

        if($env:isPR -eq $true) { 
            Extract-VersionsFormat
            Write-Output ("INFO: Pull Request detected. skip Update-Version.")
        }
        else {
	        Write-Output "env:VersionFile: $env:VersionFile"	
            Init-AppVeyorApiRequest 	
            Read-AppVeyorSettings	
	        Extract-VersionsFormat
            $env:newBuildVersion = Get-VersionFromFile
            if(-not $env:newBuildVersion) { return }    
            if(Test-NewVersionIsGreater) { Reset-BuildNumber }
            $env:buildVersion = $env:newBuildVersion
            Update-AppVeyorSettings
            Update-AppveyorBuild -Version "$env:buildVersion.$env:buildNumber$env:versionSuffix$env:versionMeta"
        }
	
        Write-Output "env:APPVEYOR_BUILD_VERSION: $env:APPVEYOR_BUILD_VERSION"
	    Write-Output "env:buildVersion: $env:buildVersion"
	    Write-Output "env:buildNumber: $env:buildNumber"
    }
    catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        Write-Output "ERROR: $($_.Exception.StackTrace)"
        exit 1
    } finalize {
        Write-Output "END: Update-Version"
    }
}

# Reset build number
function Reset-BuildNumber {
	[CmdletBinding()]param ()
    if($env:isPR -eq $true) { return } # skip if this is a pull request
    $build = @{ nextBuildNumber = $env:APPVEYOR_BUILD_NUMBER }
    $json = $build | ConvertTo-Json    
    Invoke-RestMethod -Method Put "$apiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $headers
    Write-Output "Next build number: $env:APPVEYOR_BUILD_NUMBER"
}

Export-ModuleMember -Function Update-Version, Update-VersionWithTimestamp, Reset-BuildNumber
