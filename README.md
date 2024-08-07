# AppVeyorBuildTools

A set of cmdlets to use in AppVeyor CI.

## How to use

### 1. Bootstrapper - getting cmdlets

(global-)appveyor.yml:
```yaml
init:
- ps: iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/KsWare/KsWare.AppVeyorBuildTools/develop/src/init.ps1'))
```
This will download and import all other useful cmdlets.

### 2. run common initialization code (optional)

```yaml
init:
…
- ps: Initialize-AppVeyor
…
```
## Cmdlets

Name | Description
--- | ---
[Import-AppVeyorModules](###Import-AppVeyorModules) |
[Initialize-AppVeyor](###Initialize-AppVeyor) | 
[Update-Version](###Update-Version) | 
[Publish-ToFTP](###Publish-ToFTP) | 
[Reset-BuildNumber](###Reset-BuildNumber) | 
[Install-ClickOnceCerticate](###Install-ClickOnceCerticate) | 

### Import-AppVeyorModules

Import-AppVeyorModules will download und import all other AppVeyor cmdlets.

### Initialize-AppVeyor

#### 1. InitAppVeyorApiRequest

Initializes the `$env:AppVeyorApiUrl` and `$global:AppveyorApiRequestHeaders` variable

```powershell
   $global:AppVeyorApiUrl = 'https://ci.appveyor.com/api'
   $global:AppveyorApiRequestHeaders = @{
      "Authorization" = "Bearer $env:AppVeyorApiToken"
      "Content-type" = "application/json"
      "Accept" = "application/json"
    }
```
#### 2. DetectPR

Initializes the `$env:isPR` variable

### Update-VersionWithTimestamp

initializes `$env:versionMeta` with current timestamp  
updates AppVeyor and `$env:APPVEYOR_BUILD_VERSION`

Used to create unique numbers for each buid, so it s not needed to increment the build number if the build failed.
Use `Reset-BuildNumber` in `on_failure` script

### Update-Version

```yaml

```

### Publish-ToFTP

Publishes all files from a directory to a ftp server

```powershell
Publish-ToFTP <local-dir> <remote-dir> <username> <password>
```

```powershell
Publish-ToFTP "MyProject\bin\publish" "ftp://server.name/path $env:FtpUser $env:FtpPassword
```

### Reset-BuildNumber

```powershell
Reset-BuildNumber
```

### Install-ClickOnceCerticate

```powershell
Install-ClickOnceCerticate <cert-file> <password>
```

```powershell
Install-ClickOnceCerticate mycert.pfx $env:CertPassword
```

## Environment Variables

Name | Description
---- | ---
`env:isPR` | $true if current build is a pull request; else $false
`env:BuildVersion` | "VersionPrefix" e.g. "1.2.3" (from 1.2.3.999)
`env:BuildNumber` | Auto incremented build number
`env:VersionSuffix` | Version suffix e.g. "-pre" or "-beta"
`env:VersionMeta` | Version meta part, a timestamp e.g. "+20240805213940"
`env:NewVersion` | new BuildVersion, read from file
`global:AppVeyorApiUrl` | https://ci.appveyor.com/api
`global:AppveyorApiRequestHeaders` | `@{`<br/>`    "Authorization" = "Bearer $env:AppVeyorApiToken"`<br/>`    "Content-type" = "application/json"`<br/>`    "Accept" = "application/json"`<br/>`}`
`global:AppVeyorSettings` | 
