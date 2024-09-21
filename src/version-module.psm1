function Read-AppVeyorSettings {
	Write-Verbose "Read-AppVeyorSettings"
	# Read Settings
	if($env:isPR -eq $false) {
		$response = Invoke-RestMethod -Method Get -Uri "$global:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings" -Headers $global:AppveyorApiRequestHeaders
		$global:AppVeyorSettings = $response.settings
		Write-Verbose "settings loaded"
		Write-Verbose $global:AppVeyorSettings
	} else {
		# dummy settings
		$global:AppVeyorSettings = @{versionFormat = $env:APPVEYOR_BUILD_VERSION}
		Write-Verbose "dummy settings created"
	}
	$env:versionFormat = $($global:AppVeyorSettings.versionFormat)
	Write-Verbose "  versionFormat: $env:versionFormat"
	#$txt = ConvertTo-Json -Depth 10 -InputObject $global:AppVeyorSettings
	#Write-Verbose "global:AppVeyorSettings = $txt"
	Write-Verbose "$global:AppVeyorSettings = {object}"
}

# Extract version format
function Extract-VersionsFormat {
	Write-Verbose "Extract-VersionsFormat"
	if (-not $env:versionFormat) { Write-Error "ERROR: 'versionFormat' is not set in the environment!"; Exit-AppveyorBuild }
	# supported: 1.2.3.{build}; 1.2.{build};  1.2.{build}.0
	$versionSegments = $env:versionFormat.Split(".")
	$env:VersionSegmentCount = $versionSegments.Count
	Write-Verbose "  VersionSegmentCount: $env:VersionSegmentCount"
	if ($env:VersionSegmentCount -eq 3) {
		$env:buildVersion = "$($versionSegments[0..1] -join '.').$env:APPVEYOR_BUILD_NUMBER"
		$env:buildNumber = 0
	} elseif ($env:VersionSegmentCount -eq 4) {
		if ($versionSegments[2] -eq "{build}") {
			$env:buildVersion = "$($versionSegments[0..1] -join '.').$env:APPVEYOR_BUILD_NUMBER"
			$env:buildNumber = 0
		} else {
			$env:buildVersion = "$($versionSegments[0..2] -join '.')"
			$env:buildNumber = $env:APPVEYOR_BUILD_NUMBER
		}        
	} else {
		Write-Error "ERROR: Unsupported version format. Version must have 3 or 4 segments."
		Exit-AppveyorBuild
	}

	Write-Verbose "  versionFormat: $env:versionFormat"
	$env:versionFixedSegmentCount = (("$env:versionFormat.{build}" -split ".{build}")[0]).Split(".").Count
	Write-Verbose "  versionFixedSegmentCount: $env:versionFixedSegmentCount"
	Write-Host "Current version: $env:buildVersion.$env:buildNumber"
}

# Read new version from file
function Read-VersionFromFile {
	Write-Verbose "Read-VersionFromFile"
	if($env:isPR -eq $true -or -not (Test-Path $env:VersionFile)) { return }
	
	Write-Host "Read new version from file"
	$headerPattern = "^\s*(?<level>##?)\s*.*"
	$versionPattern = "^(\s*(?<level>##?)\s*v?)(?<version>\d+\.\d+(\.\d+)?)(?<suffix>-[^\s]+)?"
	$fileContent = Get-Content -path "$env:VersionFile" -TotalCount 5

	$firstFoundHeader = $null
	$newVersion = $null

	foreach ($line in $fileContent) {
		Write-Host "  |$line"
		if ($line -match $headerPattern) {
			$currentLevel = $matches['level']
			if (-not $firstFoundHeaderLevel -or $firstFoundHeaderLevel -ne $currentLevel) {
				$firstFoundHeaderLevel = $currentLevel
				if ($line -match $versionPattern) {
					$newVersion = $matches['version']
					$newVersionSuffix = $matches['suffix']
					Write-Verbose "New version found: '$newVersion$newVersionSuffix' in line '$line'"
					break
				}
			} else {
				break
			}
		}
	}
	
	if($newVersion) {		
		$newVersionSegments = $newVersion.Split(".")    
		if($newVersionSegments.Count -ne $env:versionFixedSegmentCount) {
			Write-Verbose "false: $($newVersionSegments.Count) -ne $env:versionFixedSegmentCount"
			#$env:APPVEYOR_SKIP_FINALIZE_ON_EXIT="true"
			Write-Error -Message "`nERROR: Unsupported version format! segments: $($newVersionSegments.Count), expected: $env:versionFixedSegmentCount" -ErrorAction Stop
			Exit-AppveyorBuild
		}

		$env:newBuildVersionFormat = $env:versionFormat -replace '^\.\{build\}', "$newVersion.{build}"
		$env:newBuildVersion = $newVersion
		$env:newVersionSuffix = $newVersionSuffix

	}
	
	Write-Host "New version: $env:newBuildVersionFormat / $env:newBuildVersion.$env:buildNumber$env:versionSuffix$env:versionMeta"        
}

function ProcessVersion {
	if($env:newBuildVersion){
		if (Test-NewVersionIsGreater) {
			Reset-BuildNumber
			if ($env:versionFixedSegmentCount -eq 2) {
				$env:buildVersion = "$env:newBuildVersion.0"
			} else {
				$env:buildVersion = $env:newBuildVersion
			}
		} else {   
			$env:buildVersion = $env:newBuildVersion
		}
		if($env:newVersionSuffix) {
			$env:versionSuffix = "$newVersionSuffix.$env:buildNumber" #TODO overwrites existing suffix!
			$env:versionHasSuffix = $env:versionSuffix -ne ""
		}
	} else {
		# no new version found
		# build with existing version and incremented build number
		$env:versionSuffix = "-pre.$env:buildNumber" #TODO overwrites existing suffix!
		$env:versionHasSuffix = $true
	}
}

function Test-NewVersionIsGreater {
	Write-Verbose "Test-NewVersionIsCreater $env:buildVersion $env:newBuildVersion"
	$currentVersionSegments = $env:buildVersion.Split([char[]]('.','+','-'))
	$newVersionSegments = $env:newBuildVersion.Split([char[]]('.','+','-'))

	for ($i = 0; $i -lt ([int]$env:versionFixedSegmentCount); $i++) {
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

# Reset build number to 0 and next build number to 1
function Reset-BuildNumber {
	Write-Verbose "Reset-BuildNumber"
	if(-not $global:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
	if(-not $global:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}

	$env:buildNumber = 0
	$json = @{ nextBuildNumber = 1 } | ConvertTo-Json    
	Write-Host "Invoke 'Reset Build Nummer'"
	Invoke-RestMethod -Method Put "$global:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $global:AppveyorApiRequestHeaders
} 

function Update-AppVeyorSettings {
	Write-Verbose "Update-AppVeyorSettings"
	if(-not $global:AppVeyorSettings) {throw "global:AppVeyorSettings is empty."}
	if(-not $global:AppVeyorApiUrl) {throw "global:AppVeyorApiUrl is empty."}
	if(-not $global:AppVeyorApiRequestHeaders) {throw "global:AppVeyorApiRequestHeaders is empty."}

	$global:AppVeyorSettings.versionFormat = $env:newBuildVersionFormat
	Write-Host "Build version format: $($global:AppVeyorSettings.versionFormat)"
	$body = ConvertTo-Json -Depth 10 -InputObject $global:AppVeyorSettings
	$response = Invoke-RestMethod -Method Put -Uri "$global:AppVeyorApiUrl/projects" -Headers $global:AppVeyorApiRequestHeaders -Body $body
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
		Write-Verbose "Update-Version"
		Write-Verbose "isPR: $env:isPR"

		if($env:isPR -eq $true) { 
			Extract-VersionsFormat
			Write-Host ("INFO: Pull Request detected. skip Update-Version.")
		}
		else {
			Write-Host "env:VersionFile: $env:VersionFile"	
			Read-AppVeyorSettings	
			Extract-VersionsFormat
			Read-VersionFromFile            
			if(-not $env:newBuildVersion) { return }    
			Update-AppVeyorSettings
			Update-AppveyorBuild -Version "$env:buildVersion.$env:buildNumber$env:versionSuffix$env:versionMeta"
		}
	
		Write-Host "env:APPVEYOR_BUILD_VERSION: $env:APPVEYOR_BUILD_VERSION"
		Write-Host "env:buildVersion: $env:buildVersion"
		Write-Host "env:buildNumber: $env:buildNumber"
		Write-Host "env:versionSuffix: $env:versionSuffix"
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
	} finally {
		Write-Host "Update-Version done"
	}
}

# Reset next build number to current build number
function Reset-NextBuildNumber {
	[CmdletBinding()]param ()
	Write-Verbose "Reset-NextBuildNumber"
	if($env:isPR -eq $true) { return } # skip if this is a pull request
	$build = @{ nextBuildNumber = $env:APPVEYOR_BUILD_NUMBER }
	$json = $build | ConvertTo-Json    
	Invoke-RestMethod -Method Put "$global:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $global:AppVeyorApiRequestHeaders
	Write-Host "Next build number: $env:APPVEYOR_BUILD_NUMBER"
}

Export-ModuleMember -Function Update-Version, Update-VersionWithTimestamp, Reset-NextBuildNumber

# $env:versionFormat            1.1.{build}    1.0.0   Read-AppVeyorSettings
# $env:APPVEYOR_BUILD_NUMBER    999            999
# $env:APPVEYOR_BUILD_VERSION   1.0.999        1.0.0
# $env:useBuildNumberInVersion  true           false
# $env:newBuildVersion          1.1            1.0.1   (from ChangeLog.md)
# $env:newBuildVersionFormat    1.1.{build}    1.0.1
# $env:buildVersion             1.1.0          1.0.1

# $env:versionSuffix            -beta
# $env:versionMeta              +20241201120000
