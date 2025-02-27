
# Define the names of the modules to download
$script:moduleNames = @(
    "ftp-module",
    "version-module",
    "install-module",
    "build-module",
    "api-module"
    "common-module"
)
Write-Verbose "Modules: $script:moduleNames"

# Detect PR   
function DetectPR {
    if($env:APPVEYOR_PULL_REQUEST_NUMBER -match "^\d+$") {$isPR=$true} else {$isPR=$false}
    $env:isPR = $isPR
    Write-Output "isPR: $isPR"
} 

# Import Module from Url
function Import-ModuleFromUrl {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$uri,
        [Parameter(Position=1, Mandatory=$false)][string]$destination
    )

    # Check if $destination is not specified
    if (-not $destination) {
        $destination = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$env:USERPROFILE\*" })[0]
    }

    # Check if $destination is not a psm1-file
    if (-not $destination.EndsWith(".psm1")) {
        $uriObject = [System.Uri]::new($uri)
        $fileName = [System.IO.Path]::GetFileName($uriObject.AbsolutePath)
        $destination = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName($destination), $fileName)
    }

    $destinationDir = [System.IO.Path]::GetDirectoryName($destination)
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force}

    Invoke-WebRequest -Uri $uri -OutFile $destination -ErrorAction Stop
    Import-Module -Name $destination -Force -Scope Global -Verbose -ErrorAction Stop
}

# Imports all modules definied in $script:moduleNames
function Import-AppVeyorModules {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$baseUrl,
        [Parameter(Position=1, Mandatory=$false)][string]$destinationDir
    )
    Write-Verbose "Import-AppVeyorModules $baseUrl $destinationDir"

    # Check if destination is not specified
    if (-not $destinationDir) {
        $destinationDir = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$env:USERPROFILE\*" })[0] }

    # Check if destination is not in PSModulePath
    if ($env:PSModulePath -notlike "*$destinationDir*") {
        Write-Warning "The directory '$destinationDir' is not in the module path." }

    # Create destination if not exists
    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force }

    # Download and import each module
    Write-Verbose "Importing $($script:moduleNames.Count) modules"
    foreach ($moduleName in $script:moduleNames) {
        Write-Verbose "  Import: $moduleName"
        $moduleUrl = "$baseUrl/$moduleName.psm1"
        $modulePath = Join-Path -Path $destinationDir -ChildPath "$moduleName.psm1"
		Invoke-WebRequest -Uri $moduleUrl -OutFile $modulePath -ErrorAction Stop
		Import-Module -Name $modulePath -Force -Scope Global -DisableNameChecking -ErrorAction Stop
    }
}

function Initialize-AppVeyor {
    [CmdletBinding()] param ()

    Initialize-AppVeyorApiRequest
    DetectPR
}

Export-ModuleMember -Function *-*