# TODO install click-once certificate
function Install-ClickOnceCerticate {    
     [CmdletBinding()] param ()

    $certFile="src\KsWare.AppVeyorClient\Properties\KsWare.AppVeyorClient_TemporaryKey.pfx"
    $plainPassword = ConvertTo-SecureString -String "$env:CertFilePassword" -Force -AsPlainText
    Import-PfxCertificate -FilePath "$env:APPVEYOR_BUILD_FOLDER\$certFile" -CertStoreLocation Cert:\CurrentUser\My -Password $plainPassword -Exportable
}

Export-ModuleMember -Function *-*