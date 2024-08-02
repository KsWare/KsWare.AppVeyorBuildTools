
# Init AppVeyor API request 
function InitAppVeyorApiRequest {    
    $env:AppVeyorApiUrl = 'https://ci.appveyor.com/api'
    $env:AppveyorApiRequestHeaders = @{
      "Authorization" = "Bearer $env:AppVeyorApiToken"
      "Content-type" = "application/json"
      "Accept" = "application/json"
    }
}

# Detect PR   
function DetectPR {
    if($env:APPVEYOR_PULL_REQUEST_NUMBER -match "^\d+$") {$isPR=$true} else {$isPR=$false}
    $env:isPR = $isPR
    Write-Output "isPR: $isPR"
} 

function Init-AppVeyor {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$baseUrl,
        [Parameter(Position=1, Mandatory=$true)][string]$destinationDir
    )

    # Define the names of the modules to download
    $moduleNames = @(
        "ftp-module.psm1",
        "version-module.psm1"
    )
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force
    }

    # Download and import each module
    foreach ($moduleName in $moduleNames) {
        $moduleUrl = "$baseUrl/$moduleName"
        $destinationPath = Join-Path -Path $destinationDir -ChildPath $moduleName
		Invoke-WebRequest -Uri $moduleUrl -OutFile $destinationPath
		Import-Module -Name $destinationPath
    }
    $env:MODULE_PATH=$destinationDir

    InitAppVeyorApiRequest
    DetectPR
}

Export-ModuleMember -Function Init-AppVeyor
