function Import-AppVeyorModules {
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
}

Export-ModuleMember -Function Import-AppVeyorModules
