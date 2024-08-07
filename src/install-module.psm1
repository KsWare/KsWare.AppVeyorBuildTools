# install click-once certificate
function Install-ClickOnceCerticate {    
     [CmdletBinding()] param (
        [Parameter(Position=0, Mandatory=$true)][string]$certFile,
        [Parameter(Position=1, Mandatory=$true)][string]$password
     )
    #$certFile="src\KsWare.AppVeyorClient\Properties\KsWare.AppVeyorClient_TemporaryKey.pfx"
    #$plainPassword = ConvertTo-SecureString -String "$env:CertFilePassword" -Force -AsPlainText

    if (-not [System.IO.Path]::IsPathRooted($certFile)) {
        $certFile = [System.IO.Path]::GetFullPath((Join-Path -Path $env:APPVEYOR_BUILD_FOLDER -ChildPath $certFile))
    }
    $plainPassword = ConvertTo-SecureString -String $password -Force -AsPlainText
    Import-PfxCertificate -FilePath $certFile -CertStoreLocation Cert:\CurrentUser\My -Password $plainPassword -Exportable
}

function Clone-Repository {
    [CmdletBinding()] param ()
    # APPVEYOR_REPO_NAME             KsWare/KsWare.AppVeyorClient
    # APPVEYOR_REPO_PROVIDER         gitHub                                                                                                                                                                                                
    # APPVEYOR_REPO_SCM              git          
    if($env:APPVEYOR_REPO_PROVIDER -eq "gitHub") {
        git clone -q --branch=$env:APPVEYOR_REPO_BRANCH https://github.com/$env:APPVEYOR_REPO_NAME.git $env:APPVEYOR_BUILD_FOLDER
        git checkout -qf $env:APPVEYOR_REPO_COMMIT
    } else {
        Write-Error "Sorry, repo type '$env:APPVEYOR_REPO_PROVIDER' is not supported."
    }

}

Export-ModuleMember -Function *-*