
# Define the names of the modules to download
$script:moduleNames = @(
    "ftp-module",
    "version-module",
    "common-module"
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

    $PSVersionTable.PSVersion
    Get-ExecutionPolicy
    Write-Error "STOP"

    Write-Verbose "Import-AppVeyorModules: $baseUrl $destinationDir"

    if ($env:PSModulePath -notlike "*$destinationDir*") {
        Write-Warning "The directory '$destinationDir' is not in the module path."
    }

    if (-not (Test-Path -Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force
    }

    # Download and import each module
    foreach ($moduleName in $script:moduleNames) {
        try {
            Write-Verbose "  Import: $moduleName"
            $moduleUrl = "$baseUrl/$moduleName.psm1"
            $modulePath = Join-Path -Path $destinationDir -ChildPath "$moduleName.psm1"
		    Invoke-WebRequest -Uri $moduleUrl -OutFile $modulePath
        
		    Import-Module -Name $modulePath -Force -Scope Global -Verbose -ErrorAction Stop
            Write-Verbose "Module '$moduleName' imported successfully."    

            $module = Get-Module | Where-Object { $_.Path -eq $modulePath }
            if ($module) {
                Write-Verbose "  Module '$modulePath' loaded as '$($module.Name)'."
            } else {
                Write-Warning "  Module path '$modulePath' not found."
            }
            
            $module = Get-Module -Name $moduleName
            if ($module) {
                Write-Verbose "  Module '$moduleName' found."
            } else {
                Write-Warning "  Module '$moduleName'not found."
            }

            $functions = Get-Command -Module $moduleName -CommandType Function
            Write-Verbose "  $($functions.Count) Functions in '$moduleName':"
            foreach ($function in $functions) { Write-Verbose "    $($function.Name)" }

            $cmdlets = Get-Command -Module $moduleName -CommandType Cmdlet
            Write-Verbose "  $($cmdlets.Count) Cmdlet imported."
            foreach ($cmdlet in $cmdlets) { Write-Verbose "    $($cmdlet.Name)"}

            Write-Verbose "  Objects:"
            Get-Command -Module $moduleName | ForEach-Object {
                Write-Verbose "  $($_.Name), CommandType: $($_.CommandType)"
            }

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