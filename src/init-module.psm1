
# Define the names of the modules to download
$script:moduleNames = @(
    "ftp-module",
    "version-module",
    "common-module"
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

function Import-ModuleFromUrl {

}

# Imports all modules definied in $script:moduleNames
function Import-AppVeyorModules {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$baseUrl,
        [Parameter(Position=1, Mandatory=$true)][string]$destinationDir
    )
    Write-Verbose "Import-AppVeyorModules $baseUrl $destinationDir"

    if ($env:PSModulePath -notlike "*$destinationDir*") {
        Write-Warning "The directory '$destinationDir' is not in the module path." }

    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force }

    # Download and import each module
    Write-Verbose "Importing $($script:moduleNames.Count) modules"
    foreach ($moduleName in $script:moduleNames) {
        Write-Verbose "  Import: $moduleName"
        $moduleUrl = "$baseUrl/$moduleName.psm1"
        $modulePath = Join-Path -Path $destinationDir -ChildPath "$moduleName.psm1"
		Invoke-WebRequest -Uri $moduleUrl -OutFile $modulePath -ErrorAction Stop
		Import-Module -Name $modulePath -Force -Scope Global -Verbose -ErrorAction Stop
    }
}

function Initialize-AppVeyor {
    [CmdletBinding()] param ()

    InitAppVeyorApiRequest
    DetectPR
}

Export-ModuleMember -Function *-*