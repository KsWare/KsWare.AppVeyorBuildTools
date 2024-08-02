
# Define the names of the modules to download
$script:moduleNames = @(
    "ftp-module.psm1",
    "version-module.psm1",
    "common-module.psm1"
)
Write-Verbose "Modules: $script:moduleNames"

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

function Import-AppVeyorModules {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$baseUrl,
        [Parameter(Position=1, Mandatory=$true)][string]$destinationDir
    )
    Write-Verbose "Import-AppVeyorModules: $baseUrl $destinationDir"

    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force
    }

    # Download and import each module
    foreach ($moduleName in $script:moduleNames) {
        Write-Verbose "import: $moduleName"
        $moduleUrl = "$baseUrl/$moduleName"
        $destinationPath = Join-Path -Path $destinationDir -ChildPath $moduleName
		Invoke-WebRequest -Uri $moduleUrl -OutFile $destinationPath
		Import-Module -Name $destinationPath

        $cmdlets = Get-Command -Module $ModuleName | Where-Object { $_.CommandType -eq 'Cmdlet' }
        Write-Verbose ($cmdlets | ForEach-Object { "    $_.Name" } -join " ")
    }
    Write-Verbose "$($script:moduleNames.Count) modules imported"
    $env:MODULE_PATH=$destinationDir
}

function Initialize-AppVeyor {
    [CmdletBinding()] param ()

    InitAppVeyorApiRequest
    DetectPR
}

Export-ModuleMember -Function Import-AppVeyorModules
Export-ModuleMember -Function Initialize-AppVeyor