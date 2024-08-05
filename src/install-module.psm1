# TODO install click-once certificate
function Install-ClickOnceCerticate {    
     [CmdletBinding()] param ()

    $certFile="src\KsWare.AppVeyorClient\Properties\KsWare.AppVeyorClient_TemporaryKey.pfx"
    $plainPassword = ConvertTo-SecureString -String "$env:CertFilePassword" -Force -AsPlainText
    Import-PfxCertificate -FilePath "$env:APPVEYOR_BUILD_FOLDER\$certFile" -CertStoreLocation Cert:\CurrentUser\My -Password $plainPassword -Exportable
}

function Clone-Repository {
    [CmdletBinding()] param ()

    git clone -q --branch=$env:APPVEYOR_REPO_BRANCH https://github.com/$env:APPVEYOR_REPO_URL.git $env:APPVEYOR_BUILD_FOLDER
    git checkout -qf $env:APPVEYOR_REPO_COMMIT
}

Export-ModuleMember -Function *-*