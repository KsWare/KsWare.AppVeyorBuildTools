# AppVeyorBuildTools

A set of cmdlets to use in AppVeyor CI.

## How to use

### 1. Bootstrapper - getting more cmdlets

(global-)appveyor.yml:
```yaml
init:
- ps: |-
    $modulesUrl = "https://raw.githubusercontent.com/KsWare/KsWare.AppVeyorBuildTools/develop/src"
    $userModulesPath = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$env:USERPROFILE\*" })[0]   
    Invoke-WebRequest -Uri "$modulesUrl/init-module.psm1" -OutFile  (Join-Path $modulesPath "init-module.psm1")
    Import-Module (Join-Path $modulesPath "init-module.psm1")
    Import-AppVeyorModules $modulesUrl $userModulesPath
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
Import-AppVeyorModules |
Initialize-AppVeyor | 
[Update-Version](###Update-Version) | 
[Publish-ToFTP](###Publish-ToFTP) | 

### Import-AppVeyorModules

Import-AppVeyorModules will download und import all other AppVeyor cmdlets.

### Initialize-AppVeyor

### Update-Version

```yaml

```

### Publish-ToFTP

Publishes all files from a directory to a ftp server

```yaml

```
