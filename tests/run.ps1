# Absoluten Pfad zum aktuellen Verzeichnis ermitteln
$scriptDir = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition

# Importieren des Hauptmoduls über den absoluten Pfad
$mainModulePath = Join-Path $scriptDir 'mainmodule.psm1'
Import-Module -Name $mainModulePath -Force -Verbose

# Aufrufen der Funktion aus dem Hauptmodul
Import-SubModule -TestParam "Hello from Main Module" -scriptDir $scriptDir

Test-FtpModule

$a = 1
$b ="2"
if($a+1 -eq $b) {
	Write-Output ("true")
} else {
	Write-Output ("false")
}
