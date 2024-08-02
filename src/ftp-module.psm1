# Function for uploading files
function Upload-ToFtp {
	param (
		[Parameter(Position=0, Mandatory=$true)][string]$localFilePath,
		[Parameter(Position=1, Mandatory=$true)][string]$ftpFilePath,
		[Parameter(Position=2, Mandatory=$true)][string]$ftpUser,
		[Parameter(Position=3, Mandatory=$true)][string]$ftpPassword
	)
	 Write-Host "Upload: $localFilePath"
	 Write-Host "     -> $ftpFilePath"

	$webclient = New-Object System.Net.WebClient
	$webclient.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPassword)

	$uri = New-Object System.Uri($ftpFilePath)
	try {
		$webclient.UploadFile($uri, $localFilePath)
		Write-Host "        OK"
	} catch {
		Write-Host "$_"
		exit 1
	}
}

# Function for creating directories on the FTP server
function Create-FtpDirectory {
	param (
		[Parameter(Position=0, Mandatory=$true)][string]$path,
		[Parameter(Position=1, Mandatory=$true)][string]$ftpUser,
		[Parameter(Position=2, Mandatory=$true)][string]$ftpPassword
	)
	Write-Host "MkDir:  $path"
	
	$ftpRequest = [System.Net.FtpWebRequest]::Create($path)
	$ftpRequest.Credentials = New-Object System.Net.NetworkCredential($ftpUser, $ftpPassword)
	$ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
	try {
		$ftpResponse = $ftpRequest.GetResponse()
		$ftpResponse.Close()        
		Write-Host "        OK"
	} catch [System.Net.WebException] {
		if ($_.Exception.Response.StatusCode -eq 550) {
			Write-Host "        ERROR: 550 Verzeichnis existiert möglicherweise bereits"
		} else {
			Write-Host "        ERROR: S($_.Exception.Response.StatusCode)"
		}
	}
}

# Recurse through directories and upload files
# EXPORT
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
			Create-FtpDirectory $p $ftpUser $ftpPassword
		} else {            
			Upload-ToFtp $_.FullName $p $ftpUser $ftpPassword
		}
	}
}

Export-ModuleMember -Function Publish-ToFTP