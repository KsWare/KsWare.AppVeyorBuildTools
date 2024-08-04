# Function for uploading file
function UploadToFtp {
	param (
		[Parameter(Position=0, Mandatory=$true)][string]$localFilePath,
		[Parameter(Position=1, Mandatory=$true)][string]$ftpFilePath,
		[Parameter(Position=2, Mandatory=$true)][string]$ftpUser,
		[Parameter(Position=3, Mandatory=$true)][string]$ftpPassword
	)
	 Write-Verbose "Upload: $localFilePath"
	 Write-Verbose "     -> $ftpFilePath"

	$webclient = New-Object System.Net.WebClient
	$webclient.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPassword)

	$uri = New-Object System.Uri($ftpFilePath)
	try {
		$webclient.UploadFile($uri, $localFilePath)
		Write-Verbose "        OK"
	} catch {
		Write-Error "$_"
		exit 1
	}
}

# Function for creating directories on the FTP server
function CreateFtpDirectory {
	param (
		[Parameter(Position=0, Mandatory=$true)][string]$path,
		[Parameter(Position=1, Mandatory=$true)][string]$ftpUser,
		[Parameter(Position=2, Mandatory=$true)][string]$ftpPassword
	)
	Write-Verbose "MkDir:  $path"
	
	$ftpRequest = [System.Net.FtpWebRequest]::Create($path)
	$ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPassword)
	$ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
	try {
		$ftpResponse = $ftpRequest.GetResponse()
		$ftpResponse.Close()        
		Write-Verbose "        OK"
	} catch [System.Net.WebException] {
		if ($_.Exception.Response.StatusCode -eq 550) {
			Write-Verbose "        ERROR: 550 Verzeichnis existiert möglicherweise bereits"
		} else {
			Write-Error "        ERROR: S($_.Exception.Response.StatusCode)"
		}
	}
}


<#
.SYNOPSIS
    Recurse through directories and uploads files

.PARAMETER $localPath
    path to a local directory

.PARAMETER $ftpPath
    URL to ftp server including directory

.PARAMETER $ftpUser
	FTP user name

.PARAMETER $ftpPassword
	FTP password

.EXAMPLE
    Publish-ToFTP C:\LocalDir ftp://server.name/remoteDir Foo password
#>
function Publish-ToFTP {
	[CmdletBinding()]
	param (
		[Parameter(Position=0, Mandatory=$true)][string]$localPath,
		[Parameter(Position=1, Mandatory=$true)][string]$ftpPath,
		[Parameter(Position=2, Mandatory=$true)][string]$ftpUser,
		[Parameter(Position=3, Mandatory=$true)][string]$ftpPassword
	)

	Get-ChildItem -Path $localPath -Recurse | ForEach-Object {
		$fullname = $_.FullName
		$relativePath = $fullName.Substring($localPath.Length + 1).Replace("\", "/")
		$p = "$ftpPath/$relativePath"
		if ($_.PSIsContainer) {            
			CreateFtpDirectory $p $ftpUser $ftpPassword
		} else {            
			UploadToFtp $_.FullName $p $ftpUser $ftpPassword
		}
	}
}

function Test-FtpModule {
	[CmdletBinding()] param ()
	Write-Warning("Test-FtpModule OK")
}

Export-ModuleMember -Function *-*