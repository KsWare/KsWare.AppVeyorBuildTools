function Get-Env {
    [CmdletBinding()] param ()

    Get-ChildItem Env:
}

# lists the environment variables whose names begin with APPVEYOR_.
function Get-EnvAppVeyor {
    [CmdletBinding()] param ()

    Get-ChildItem Env: | Where-Object { $_.Name -like 'APPVEYOR_*' }
}

Export-ModuleMember -Function Get-Env
Export-ModuleMember -Function Get-Foo