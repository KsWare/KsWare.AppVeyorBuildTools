
# Define the names of the modules to download
$script:moduleNames = @(
    "ftp-module.psm1",
    "version-module.psm1",
    "common-module.psm1"
)
Write-Verbose "Modules: $script:moduleNames"

# Init AppVeyor API request 
function InitAppVeyorApiRequest {    
    $env:AppVeyorApiUrl = 'https://ci.appveyor.com/api'
    $env:AppveyorApiRequestHeaders = @{
      "Authorization" = "Bearer $env:AppVeyorApiToken"
      "Content-type" = "application/json"
      "Accept" = "application/json"
    }
}

# Detect PR   
function DetectPR {
    if($env:APPVEYOR_PULL_REQUEST_NUMBER -match "^\d+$") {$isPR=$true} else {$isPR=$false}
    $env:isPR = $isPR
    Write-Output "isPR: $isPR"
} 

# Imports all modules definied in $script:moduleNames
function Import-AppVeyorModules {
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true)][string]$baseUrl,
        [Parameter(Position=1, Mandatory=$true)][string]$destinationDir
    )
    Write-Verbose "Import-AppVeyorModules: $baseUrl $destinationDir"

    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force
    }

    # Download and import each module
    foreach ($moduleName in $script:moduleNames) {
        try {
            Write-Verbose "  Import: $moduleName"
            $moduleUrl = "$baseUrl/$moduleName"
            $modulePath = Join-Path -Path $destinationDir -ChildPath $moduleName
		    Invoke-WebRequest -Uri $moduleUrl -OutFile $modulePath

            $content = Get-Content -Path $modulePath -Raw
            Write-Verbose "  Content of the module file:"
            Write-Verbose $content
        
		    Import-Module -Name $modulePath -Force -Verbose -ErrorAction Stop
            Write-Verbose "Module '$moduleName' imported successfully."        

            $module = Get-Module -Name $modulePath
            if ($module) {
                Write-Verbose "  Module $moduleName is loaded."
            } else {
                Write-Verbose "  Module $moduleName is not loaded."
            }

            $functions = Get-Command -Module $modulePath -CommandType Function
            Write-Verbose "  $($functions.Count) Functions in '$moduleName':"
            foreach ($function in $functions) {
                Write-Verbose "    $($function.Name)"
            }

            $cmdlets = Get-Command -Module $modulePath
            foreach ($cmdlet in $cmdlets) { Write-Verbose "    $($cmdlet.Name)"}
            Write-Verbose "  $($cmdlets.Count) functions imported."
        } catch {
            Write-Error "ERROR: Something went wrong when importing the module '$moduleName'.`n$_"
        }
    }
    Write-Verbose "  $($script:moduleNames.Count) modules imported"
    $env:MODULE_PATH=$destinationDir
}

function Initialize-AppVeyor {
    [CmdletBinding()] param ()

    InitAppVeyorApiRequest
    DetectPR
}

Export-ModuleMember -Function Import-AppVeyorModules
Export-ModuleMember -Function Initialize-AppVeyor