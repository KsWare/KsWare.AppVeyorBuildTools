function Import-SubModule {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$TestParam,
        [Parameter(Position=1, Mandatory=$true)][string]$scriptDir
    )
    $subModulePath = Join-Path $scriptDir 'submodule.psm1'

    Import-Module -Name $subModulePath -Force -Verbose -Scope Global
    Import-Module -Name $(Join-Path $scriptDir '..\src\ftp-module.psm1') -Force -Verbose -Scope Global

    Test-SubModuleCmdlet -TestParam $TestParam
    Test-FtpModule
}

Export-ModuleMember -Function Import-SubModule
