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

function Read-PublishProfile {
    [CmdletBinding()] param (
        [Parameter(Position=0, Mandatory=$true)][string]$name
     )
    $repositoryPath = $env:APPVEYOR_BUILD_FOLDER
    $fileName = "$name.pubxml"
    $profiles = Get-ChildItem -Path $repositoryPath -Recurse -Filter *.pubxml | Where-Object { $_.Name -eq $fileName }

    if ($publishProfiles.Count -eq 0) {
        Write-Error "No publish profile found with the name '$profileName'."
        Exit-AppVeyorBuild
    } elseif ($publishProfiles.Count -gt 1) {
        Write-Warning "Profile name '$name' is ambigous. First one is used."
    }
    $pubxmlFile = $profiles[0]
    Write-Host "Profile: $pubxmlFile"

    $projectFilePattern = ".*\.(csproj|vbproj|fsproj)$"
    while ($directory -ne (Get-Item $directory).PSDrive.Root) {
        $projectFiles = Get-ChildItem -Path $directory -File | Where-Object { $_.Name -match $projectFilePattern }
        if ($projectFiles) { $projectPath = $directory; break }
        $directory = Split-Path -Parent $directory
    }
    if ($projectPath -eq $null) {
        Write-Error "No project file found."
        Exit-AppVeyorBuild
    }

    [xml]$pubxml = Get-Content $pubxmlFile
    $global:PublishProfileContent = $pubxml
    $env:PublishDir = "$projectPath\$($pubxml.Project.PropertyGroup.PublishDir.TrimEnd('\'))"   # bin\Release\net8.0-windows\app.publish\
    $env:PublishUrl = "$projectPath\$($pubxml.Project.PropertyGroup.PublishUrl.TrimEnd('\'))"	# bin\Publish
    Write-Host "env:PublishDir: $env:PublishDir"
    Write-Host "env:PublishUrl: $env:PublishUrl"
}

Export-ModuleMember -Function *-*