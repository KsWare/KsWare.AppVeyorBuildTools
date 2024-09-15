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
[Reset-NextBuildNumber](###Reset-NextBuildNumber) | Reset next build number to current build number
[Install-ClickOnceCerticate](###Install-ClickOnceCerticate) | 
[Read-PublishProfile](###Read-PublishProfile) | 

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

Resets the current build number to 0 and next build number to 1.

Used by [Update-Version](###Update-Version) if the new version is greater then old version.

current: 1.2.3.444, new: 1.3.0 results in 1.3.0.0

```powershell
Reset-BuildNumber
```

### Reset-NextBuildNumber

Resets the next build number to current build number (Reverts the auto-increment).

```yaml
on_failure:
- ps: Reset-NextBuildNumber
```

### Install-ClickOnceCerticate

```powershell
Install-ClickOnceCerticate <cert-file> <password>
```

```powershell
Install-ClickOnceCerticate mycert.pfx $env:CertPassword
```

### Read-PublishProfile

```powershell
Read-PublishProfile <profile-name>
```
```powershell
Read-PublishProfile "ClickOnceProfile"
```
Result:  
`global:PublishProfileContent` The publish profile content [xml]  
`env:PublishDir` contains full path of \<PublishDir>  
`env:PublishUrl` contains full path of \<PublishUrl>

## Environment Variables

Name | Description | Example
---- | ---
`env:isPR` | $true if current build is a pull request; else $false
`env:BuildVersion` | "VersionPrefix" | `1.2.3` (from 1.2.3.999)
`env:BuildNumber` | Auto incremented build number | `999`
`env:VersionSuffix` | Version suffix | `-pre` or `-beta`
`env:VersionMeta` | Version meta part, a timestamp | `+20240805213940`
`env:NewVersion` | new BuildVersion, read from file | `1.3.0`
`env:VersionFormat` | 'Build version format' from AppVeyorSettings | `1.2.3.{build}`
`env:NewVersionFormat` | new 'Build version format' | `1.3.0.{build}`
`global:AppVeyorApiUrl` | | https://ci.appveyor.com/api
`global:AppveyorApiRequestHeaders` || `@{`<br/>`  "Authorization" = "Bearer $env:AppVeyorApiToken"`<br/>`  "Content-type" = "application/json"`<br/>`  "Accept" = "application/json"`<br/>`}`
`global:AppVeyorSettings` | 

