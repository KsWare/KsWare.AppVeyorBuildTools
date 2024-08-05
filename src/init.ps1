$modulesUrl = "https://raw.githubusercontent.com/KsWare/KsWare.AppVeyorBuildTools/develop/src"
$modulesPath = ($env:PSModulePath -split ';' | Where-Object { $_ -like "$env:USERPROFILE\*" })[0]   
Invoke-WebRequest -Uri "$modulesUrl/init-module.psm1" -OutFile  (Join-Path $modulesPath "init-module.psm1")
Import-Module (Join-Path $modulesPath "init-module.psm1") -Force -Scope Global -ErrorAction Stop -verbose
Import-AppVeyorModules -baseUrl $modulesUrl -destinationDir $modulesPath -Verbose