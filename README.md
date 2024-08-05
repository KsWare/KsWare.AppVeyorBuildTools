# AppVeyorBuildTools

A set of cmdlets to use in AppVeyor CI.

## How to use

### 1. Bootstrapper - getting more cmdlets

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

### Import-AppVeyorModules

Import-AppVeyorModules will download und import all other AppVeyor cmdlets.

### Initialize-AppVeyor

#### 1. InitAppVeyorApiRequest

Initializes the `$env:AppVeyorApiUrl` and `$env:AppveyorApiRequestHeaders` variable

```powershell
   $env:AppVeyorApiUrl = 'https://ci.appveyor.com/api'
   $env:AppveyorApiRequestHeaders = @{
      "Authorization" = "Bearer $env:AppVeyorApiToken"
      "Content-type" = "application/json"
      "Accept" = "application/json"
    }
```
#### 2. DetectPR

Initializes the `$env:isPR` variable

### Update-VersionWithTimestamp

initializes `$enc:version_meta` with current timestamp  
updates AppVeyor and `$env:APPVEYOR_BUILD_VERSION`

Used to create unique numbers for each buid, so it s not needed to increment the build number if the build failed.
Use `Reset-BuildNumber` in `on_failure` script

### Update-Version

```yaml

```

### Publish-ToFTP

Publishes all files from a directory to a ftp server

```yaml

```

### Reset-BuildNumber


