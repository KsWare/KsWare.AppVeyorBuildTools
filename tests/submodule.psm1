function Test-SubModuleCmdlet {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$TestParam
    )
    Write-Host "Test-SubModuleCmdlet called with parameter: $TestParam"
}

Export-ModuleMember -Function Test-SubModuleCmdlet
