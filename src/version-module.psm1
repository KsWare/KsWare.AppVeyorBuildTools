
# Init AppVeyor API request 
function Init-AppVeyorApiRequest {
	$env:AppveyorApiUrl = 'https://ci.appveyor.com/api'
	$env:AppveyorApiRequestHeaders = @{
		"Authorization" = "Bearer $env:AppVeyorApiToken"
		"Content-type" = "application/json"
		"Accept" = "application/json"
	}
}

function Read-AppveyorSettings {
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
    if($env:isPR -eq $true -or -not (Test-Path $env:VersionFile)) { return }
    
    Write-Output "Read new version from file"
    $versionPattern = "^(\s*\##?\s*v?)(?<version>\d+\.\d+\.\d+)"
    $fileContent = Get-Content -path "$env:VersionFile" -TotalCount 5
    foreach ($line in $fileContent) {
        if ($line -match $versionPattern) {
            $env:NewVersion = $matches['version']
            break
        }
    }    	
    if(-not ($newVersion)) {
        Write-Error -Message "`nERROR: No valid version found!" -ErrorAction Stop
        Exit-AppveyorBuild
    }	
    $newVersionSegments = $newVersion.Split(".")	
    if($newVersionSegments.Count+1 -ne $env:VersionSegmentCount) {
        $env:APPVEYOR_SKIP_FINALIZE_ON_EXIT="true"
        Write-Error -Message "`nERROR: Unsupported version format!" -ErrorAction Stop
        Exit-AppveyorBuild
    }

    Write-Output "New version: ""$env:NewVersion.*"" / $($newVersionSegments.Count+1) parts"	
    return $env:NewVersion
}

function Test-NewVersionIsCreater {
    $currentVersionSegments = $env:buildVersion.Split(".")
    $newVersionSegments = $env:newVersion.Split(".")

    for ($i = 0; $i -lt $currentVersionSegments.Length; $i++) {
        if ([int]$newVersionSegments[$i] -gt [int]$currentVersionSegments[$i]) { return $true } 
        if ([int]$newVersionSegments[$i] -lt [int]$currentVersionSegments[$i]) { throw "New version is smaller than current version." }
    }
    return $false
}

function Reset-BuildNumber {
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

function Update-Version {
	[CmdletBinding()]param ()
    try {
	    Write-Output "START: Update-Version()"
	    Write-Output "isPR: $env:isPR"

        if($env:isPR -eq $true) { 
            Write-Output "A"
            Extract-VersionsFormat
            Write-Output ("INFO: Pull Request detected. skip Update-Version.")
        }
        else {
            Write-Output "B"
            $isPR = $env:isPR
	        Write-Output "env:VersionFile: $env:VersionFile"
	
            Init-AppVeyorApiRequest 	
            Read-AppVeyorSettings	
	        Extract-VersionsFormat
            $newVersion = Get-VersionFromFile
            if(-not $newVersion) { return }    
            $env:buildVersion = $newVersion
            if(Test-NewVersionIsGreater) { Reset-BuildNumber }
            Update-AppVeyorSettings
            Update-AppveyorBuild -Version "$env:buildVersion.$env:buildNumber$env:versionSuffix$env:versionMeta"
        }
	
        Write-Output "env:APPVEYOR_BUILD_VERSION: $env:APPVEYOR_BUILD_VERSION"
	    Write-Output "env:buildVersion: $env:buildVersion"
	    Write-Output "env:buildNumber: $env:buildNumber"
	    Write-Output "END: Update-Version()"
    }
    catch {
        Write-Output "ERROR: $($_.Exception.Message)"
        Write-Output "ERROR: $($_.Exception.StackTrace)"
        exit 1
    }
}

Export-ModuleMember -Function Update-Version
