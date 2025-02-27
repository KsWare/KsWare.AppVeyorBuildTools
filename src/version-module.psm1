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
		$env:versionPrefix = "$($versionSegments[0..1] -join '.').$env:APPVEYOR_BUILD_NUMBER"
		$env:buildNumber = 0
	} elseif ($env:VersionSegmentCount -eq 4) {
		if ($versionSegments[2] -eq "{build}") {
			$env:versionPrefix = "$($versionSegments[0..1] -join '.').$env:APPVEYOR_BUILD_NUMBER"
			$env:buildNumber = 0
		} else {
			$env:versionPrefix = "$($versionSegments[0..2] -join '.')"
			$env:buildNumber = $env:APPVEYOR_BUILD_NUMBER
		}        
	} else {
		Write-Error "ERROR: Unsupported version format. Version must have 3 or 4 segments."
		Exit-AppveyorBuild
	}

	Write-Verbose "  versionFormat: $env:versionFormat"
	$env:versionFixedSegmentCount = (("$env:versionFormat.{build}" -split ".{build}")[0]).Split(".").Count
	Write-Verbose "  versionFixedSegmentCount: $env:versionFixedSegmentCount"
	Write-Host "Current version: $env:versionPrefix.$env:buildNumber"
}

# Read new version from file
function Read-VersionFromFile {
	Write-Verbose "Read-VersionFromFile"
	if($env:isPR -eq $true -or -not (Test-Path $env:VersionFile)) { return }

	$headerPattern = "^\s*(?<level>##?)\s*.*"
	$versionPattern = "^(\s*(?<level>##?)\s*v?)(?<version>\d+\.\d+(\.\d+)?)(?<suffix>(-\S+)?)"
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
					$newVersionSuffix = $matches['suffix']
					$newVersion = $matches['version']
					Write-Host "Data found: '$newVersion' and '$newVersionSuffix' in line '$line'"
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
			Write-Error -Message "`nERROR: Unsupported version format! segments: $($newVersionSegments.Count), expected: $env:versionFixedSegmentCount" -ErrorAction Stop
			Exit-AppveyorBuild
		}
		$env:newVersionPrefixFormat = $env:versionFormat -replace '.*\.\{build\}', "$newVersion.{build}"
		$env:newVersionPrefix = $newVersion
		$env:newVersionSuffix = $newVersionSuffix
	}
	
	Write-Host "New version: $env:newVersionPrefixFormat / $env:newVersionPrefix.$env:buildNumber$env:newVersionSuffix"        
}

function ProcessVersion {
	if($env:newVersionPrefix){
		if (Test-NewVersionIsGreater) {
			Reset-BuildNumber
			if ($env:versionFixedSegmentCount -eq 2) {
				$env:versionPrefix = "$env:newVersionPrefix.0"
			} else {
				$env:versionPrefix = $env:newVersionPrefix
			}
		} else {
			$env:versionPrefix = $env:newVersionPrefix
		}
		if($env:newVersionSuffix) {
			$env:versionSuffix = "$env:newVersionSuffix.$env:buildNumber" #TODO overwrites existing suffix!
			$env:versionHasSuffix = $env:versionSuffix -ne ""
		}
	} else {
		# no new version found
		# build with existing version and incremented build number
		$env:versionSuffix = "-pre.$env:buildNumber" #TODO overwrites existing suffix!
		$env:versionHasSuffix = $true
	}

	CalculateVersion
	Write-Host "Version: $env:Version"  

	if(-not $env:newVersionPrefix) { return }    
	Update-AppVeyorSettings
	Update-AppveyorBuild -Version $env:Version
}

function CalculateVersion {
	$meta = $env:VersionMeta
	if ($meta -and $meta -notmatch '^\+') { $meta="+$meta" }

	if ($env:VersionSuffix -and $env:VersionSuffix -ne "") {
		if ($env:VersionSuffix -match '^-') {
			$env:Version = "$env:VersionPrefix$env:VersionSuffix$meta"
		} else {
			$env:Version = "$env:VersionPrefix-$env:VersionSuffix$meta"
		}
		$env:InformationalVersion = $env:Version
	} else {
		$env:Version = "$env:VersionPrefix$meta"
		$env:InformationalVersion = "$env:VersionPrefix.$env:BuildNumber$meta"
	}
}

function Test-NewVersionIsGreater {
	Write-Verbose "Test-NewVersionIsCreater $env:versionPrefix $env:newVersionPrefix"
	$currentVersionSegments = $env:versionPrefix.Split([char[]]('.','+','-'))
	$newVersionSegments = $env:newVersionPrefix.Split([char[]]('.','+','-'))

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

function Reset-BuildNumber {
	Write-Verbose "Reset-BuildNumber"
	$env:buildNumber = 0
	$env:nextBuildNumber = 1
	SendNextBuildNumber
}

# Reset build number to 0 and next build number to 1
function SendNextBuildNumber {
	if($env:isPR -eq $true) { return }
	if(-not $env:nextBuildNumber) { return }	

	Write-Verbose "Send-NextBuildNumber"
	if(-not $global:AppVeyorApiUrl) {throw "env:AppVeyorApiUrl is empty."}
	if(-not $global:AppVeyorApiRequestHeaders) {throw "env:AppVeyorApiRequestHeaders is empty."}
	
	$json = @{ nextBuildNumber = $env:nextBuildNumber } | ConvertTo-Json    
	Write-Host "Invoke 'Reset Build Nummer'"
	Invoke-RestMethod -Method Put "$global:AppVeyorApiUrl/projects/$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG/settings/build-number" -Body $json -Headers $global:AppveyorApiRequestHeaders
	Write-Host "Next build number: $env:nextBuildNumber"
} 

function Update-AppVeyorSettings {
	Write-Verbose "Update-AppVeyorSettings"
	if(-not $global:AppVeyorSettings) {throw "global:AppVeyorSettings is empty."}
	if(-not $global:AppVeyorApiUrl) {throw "global:AppVeyorApiUrl is empty."}
	if(-not $global:AppVeyorApiRequestHeaders) {throw "global:AppVeyorApiRequestHeaders is empty."}

	$global:AppVeyorSettings.versionFormat = $env:newVersionPrefixFormat
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
			ProcessVersion			
		}
	
		Write-Host "env:APPVEYOR_BUILD_VERSION: $env:APPVEYOR_BUILD_VERSION"
		Write-Host "env:versionPrefix: $env:versionPrefix"
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
	$env:nextBuildNumber = $env:APPVEYOR_BUILD_NUMBER
	SendNextBuildNumber
}

Export-ModuleMember -Function Update-Version, Update-VersionWithTimestamp, Reset-NextBuildNumber

# $env:versionFormat            1.1.{build}    1.0.0   Read-AppVeyorSettings
# $env:APPVEYOR_BUILD_NUMBER    999            999
# $env:APPVEYOR_BUILD_VERSION   1.0.999        1.0.0
# $env:useBuildNumberInVersion  true           false
# $env:newVersionPrefix          1.1            1.0.1   (from ChangeLog.md)
# $env:newVersionPrefixFormat    1.1.{build}    1.0.1
# $env:versionPrefix             1.1.0          1.0.1

# $env:versionSuffix            -beta
# $env:versionMeta              +20241201120000
