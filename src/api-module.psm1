
# Init AppVeyor API request 
function Initialize-AppVeyorApiRequest {
     [CmdletBinding()] param ()
    $global:AppVeyorApiUrl = 'https://ci.appveyor.com/api'
    $global:AppveyorApiRequestHeaders = @{
      "Authorization" = "Bearer $env:AppVeyorApiToken"
      "Content-type" = "application/json"
      "Accept" = "application/json"
    }
}

Export-ModuleMember -Function *-*