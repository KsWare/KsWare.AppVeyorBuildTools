function Import-SubModule {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$TestParam,
        [Parameter(Position=1, Mandatory=$true)][string]$scriptDir
    )
    $subModulePath = Join-Path $scriptDir 'submodule.psm1'
    Import-Module -Name $subModulePath -Force -Verbose
    Test-SubModuleCmdlet -TestParam $TestParam
    #OK bis hier

    Import-Module -Name .\..\src\ftp-module.psm1 -Force -Verbose
    Test-FtpModule
}

Export-ModuleMember -Function Import-SubModule
