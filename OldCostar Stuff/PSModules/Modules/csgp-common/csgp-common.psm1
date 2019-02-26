#REQUIRES -Version 2.0

#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


<#
.SYNOPSIS
Asks the user a Y or N question
Version 1.00

.DESCRIPTION

.EXAMPLE
$answer = promptYN -question "Are you sure you want to break something? Y/N"

#>
function promptYN {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	# The question string for the user
	[Parameter(Mandatory=$False,ValueFromPipeline=$false)]
	[string]$question = "Are you sure? (y/n)",
	[Parameter(Mandatory = $False, ValueFromPipeline = $false)]
	[string]$foreGroundColor = [console]::ForegroundColor
	)

	BEGIN	{

	}
	
	PROCESS
	{
		
		$origForegroundColor = [console]::ForegroundColor
		[console]::ForegroundColor = $foreGroundColor
		$promptResult = Read-Host "$question"
		[console]::ForegroundColor = $origForegroundColor
		if ( ($promptResult -ne 'n') -and ($promptResult -ne 'y') ) {
			promptYN -question $question -foreGroundColor $foreGroundColor
			
		} else {
			Write-Output $promptResult
		}
	}
	END	{

	}	

}

<#
.SYNOPSIS
Version 1.0
Send smtp mail with optional attachment.

.DESCRIPTION
You can leave out -smtpAttach in the call and the script will not send an attachement

.EXAMPLE
send-Mail -smtpTo bconrad@costar.com -smtpSubject "test" -smtpBody "my body" -smtpServer dcrelay1.costar.com -smtpFrom "bconrad@costar.com  -smtpAttach "h:\servers.txt"
.EXAMPLE
send-Mail -smtpTo bconrad@costar.com -smtpSubject "test" -smtpBody "my body" -smtpServer dcrelay1.costar.com -smtpFrom "bconrad@costar.com
.EXAMPLE
send-Mail -smtpTo "Address1@costar.com,Address2@costar.com" -smtpSubject "test" -smtpBody "my body" -smtpServer dcrelay1.costar.com -smtpFrom "bconrad@costar.com
Send email to multiple users


#>
function send-Mail 	{
[cmdletBinding()]
		param(
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpTo,
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpFrom,
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpSubject,
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
				$smtpBody,
			[Parameter(Mandatory=$False,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpAttach=$('empty'),
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpServer
		)
	
	

	$msg = new-object Net.Mail.MailMessage
	$smtp = new-object Net.Mail.SmtpClient($smtpServer)
	

	#$msg.From = $env:computername + $smtpFromDomain
	$msg.From = $smtpFrom
	$msg.To.Add($smtpTo)
	$msg.Subject = $smtpSubject
	$msg.Body = $smtpBody
	$msg.IsBodyHTML = $true
	if (! $smtpAttach -match 'empty')	{
		$att = new-object Net.Mail.Attachment($smtpAttach)
		$msg.Attachments.Add($att)
	}

	$smtp.Send($msg)

}


function get-ping  {
	[cmdletBinding()]
		param(
			[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
			[PSObject[]]$computer,
			[Parameter(Mandatory = $false, ValueFromPipeline = $false)] # Required and accepts pipeline input
			[PSObject[]]$pingTimeoutMs = 500 # wait 500ms until giving up
			)

	BEGIN {
		#$pingTimeoutMs = 500 # wait 500ms until giving up
	}

	PROCESS {
		foreach ($item in $computer)	{
			$obj = "" | Select-Object Server,Result,IPV4,ResponseTime,TimeStamp,StatusCode
			
			$dateStamp = get-mydate
			
			# http://msdn.microsoft.com/en-us/library/aa394350%28VS.85%29.aspx
			# we will run this two times so that we can "warm" up the ARP cache on the server running this module.
			# An ARP cache miss can cause undesired response time
			# $p = Get-WmiObject -Class Win32_PingStatus -Filter "Address=`'$item`' and BufferSize=32 and Timeout=400" -ComputerName .
			$p = Get-WmiObject -Class Win32_PingStatus -Filter "Address=`'$item`' and BufferSize=32 and Timeout=$pingTimeoutMs" -ComputerName .
			
			if ($p.StatusCode -ne 0)	{
				$ping_result = 'FAIL'
			} else {
				$ping_result = 'PASS'
			}
			$obj.Server = $item
			$obj.Result = $ping_result
			$obj.StatusCode = $p.StatusCode
			try
			{
				$ipv4 = $p.IPV4Address.IPAddressToString
			}
			catch
			{
				$ipv4 = 'n/a'
			}
			$obj.IPV4 = $ipv4
			$obj.responsetime = $p.responsetime
			$obj.TimeStamp = $dateStamp
				
			return $obj
		}

	}
		
	END {
	
	}
}	# end get-ping


function get-mydate {
	[cmdletBinding()]
		param(
			
			)
			
	$d = Get-Date
	$nowTime = "$($d.ToShortDateString())" + " " + "$($d.Hour):$($d.Minute):$($d.Second):$($d.Millisecond)"	# looks like 6/28/2012 20:52:14:871
			
	Return $nowTime

}


<#
.SYNOPSIS
Ensures we have a valid A record for the VMhost
Version 1.00

.DESCRIPTION
There is no output if this command does not fail

.EXAMPLE
test-DnsARecord -hostname dcvmhprd341.us.costar.local

#>
function test-DnsARecord
{
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$hostname
	)
	
	BEGIN
	{
		
	}
	PROCESS
	{
		
		try
		{
			$a = [System.Net.Dns]::GetHostEntry($hostname)
			$obj = @()
			$obj = "" | Select-Object HOSTNAME,AddressList
			$obj.Hostname = $a.HostName
			$obj.AddressList = $a.AddressList[0]
			Write-Output $obj
		}
		catch
		{
			Write-Error "No DNS `'A`' record found for $hostname, if you have manually created the record and continue to get this error run ipconfig /flushdns "
		}
	}
	END
	{
		
	}
	
}

<#
.SYNOPSIS
Ensures we have a valid PTR record for the VMhost
Version 1.00

.DESCRIPTION


.EXAMPLE
test-DnsptrRecord -hostname dcvmhprd341.us.costar.local

#>
function test-DnsPtrRecord
{
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$hostname
	)
	
	BEGIN
	{
		
	}
	PROCESS
	{
		
		try
		{
			$ptr = [System.Net.Dns]::GetHostEntry($hostname)
			$obj = @()
			$obj = "" | Select-Object HOSTNAME, AddressList
			$obj.Hostname = $ptr.HostName
			$obj.AddressList = $ptr.AddressList[0].IPAddressToString
			Write-Output $obj
			
		}
		catch
		{
			Write-Error "No DNS `'PTR`' record found for $hostname"
		}
	}
	END
	{
		
	}
	
}

function Test-WMI
{
	<#
	.SYNOPSIS
	Tests to make sure we can connect to a remote server using WMI
	.DESCRIPTION
	Describe the function in more detail
	.EXAMPLE
	Give an example of how to use it
	.EXAMPLE
	Give another example of how to use it
	.PARAMETER computername
	The computer name to query. Just one.
	.PARAMETER logname
	The name of a file to write failed computer names to. Defaults to errors.txt.
	#>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string[]]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		
		
		try
		{
			$wmiOs = Get-WmiObject -Class Win32_OperatingSystem -Computer $computer
			
			if ($wmiOs.Caption)
			{
				$obj = @()
				$obj = "" | Select-Object ComputerName, WmiTestStatus
				Write-Verbose "Successfully connected to $computer using WMI ($($wmiOs.Caption))"
				$obj.Computername = $computer
				$obj.WmiTestStatus = 'Pass'
				Write-Output $obj
			}
			
		}
		catch
		{
			# Write-Warning "Test-WMI: Unable to connect to $computer using WMI"
			$obj = @()
			$obj = "" | Select-Object ComputerName, WmiTestStatus
			$obj.Computername = $computer
			$obj.WmiTestStatus = 'Fail'
			Write-Output $obj
			return
		}
	}
	
	End
	{
		
	}
}


<#
.SYNOPSIS
These functions allow one to easily save network credentials to disk in a relatively
			secure manner.  The resulting on-disk credential file can only [1] be decrypted
			by the same user account which performed the encryption.  For more details, see
			the help files for ConvertFrom-SecureString and ConvertTo-SecureString as well as
			MSDN pages about Windows Data Protection API.


.DESCRIPTION
Modified by: Ben
Origial Author: 	Hal Rottenberg <hal@halr9000.com>
 Url:		http://halr9000.com/article/tag/lib-authentication.ps1


.PARAMETER  CredFilePath
The full path to the credential file you intend to load

.PARAMETER Username
Pre-load the username into the credentials UI

.PARAMETER Message
Supply a custom message for the UI


.EXAMPLE

Export credentials, UI will prompt for username and password

import-module csgp-common -force
export-pscredential -CredFilePath MyApp.xml

.EXAMPLE

Export credentials, UI will prompt for password only

import-module csgp-common -force
export-pscredential -CredFilePath MyApp.xml -username svcMyService


.EXAMPLE

Export credentials, UI will prompt for password only and we supply a custom message

import-module csgp-common -force
export-pscredential -CredFilePath MyApp.xml -username 'US\svcMyService' -Message "Make sure to store password the password safe"


#>
function Export-PSCredential
{
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$CredFilePath,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$username,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Message
	)
	
	if ($username)
	{
		Write-Verbose "Username was specified"
		if ($Message)
		{
			$customMessage = $Message
		}
		else
		{
			$customMessage = "Enter your password"
		}
		$credential = Get-Credential -username $username -message $customMessage
	}
	else
	{
		Write-Verbose "Username not specified"
		if ($Message)
		{
			$customMessage = $Message
		}
		else
		{
			$customMessage = "Enter your username and password"
		}
		$credential = Get-Credential -message $customMessage
	}
	
	# Create temporary object to be serialized to disk
	$export = "" | Select-Object Username, EncryptedPassword
	
	# Give object a type name which can be identified later
	$export.PSObject.TypeNames.Insert(0, 'ExportedPSCredential')
	
	$export.Username = $Credential.Username
	
	# Encrypt SecureString password using Data Protection API
	# Only the current user account can decrypt this cipher
	$export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString
	
	# Export using the Export-Clixml cmdlet
	$export | Export-Clixml $CredFilePath
	
	# Return FileInfo object referring to saved credentials
	#Get-Item $CredFilePath
	Get-ChildItem -Path $CredFilePath
}

<#
 

.SYNOPSIS
Imports an xml file that was encrypted with the Windows Data Protection API (DPAPI)


.DESCRIPTION
Modified by: Ben
Origial Author: 	Hal Rottenberg <hal@halr9000.com>
 Url:		http://halr9000.com/article/tag/lib-authentication.ps1
 

.PARAMETER  CredFilePath
The full path to the credential file you intend to load

.OUTPUTS
System.String.

.EXAMPLE

Obtain a PSCredential and use with any powershell module/snapin that understands PSCredentials (PowerCli, UCSPowerTool, etc)

import-module csgp-common -force
$cred = Import-PSCredential -CredFilePath Myapp1.xml

.EXAMPLE

Obtain a PSCredential and decrypt the password.  Can be used for commands that do not understand PSCredential

import-module csgp-common -force
$cred = Import-PSCredential -CredFilePath Myapp1.xml
$username = $cred.username
$password = $cred.GetNetworkCredential().password
naviseccli.exe -user $username -Password $password -h dcsan100-spa getagent


.NOTES
Only the user who encrypted the credtentials file may decrypt the file.  Anybody who has your Windows username/password
will be able to decrypt this file

#>
function Import-PSCredential
{
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$CredFilePath
	)
	
	# Import credential file
	$import = Import-Clixml $CredFilePath
	
	# Test for valid import
	if (!$import.UserName -or !$import.EncryptedPassword)
	{
		Throw "Input is not a valid ExportedPSCredential object, exiting."
	}
	$Username = $import.Username
	
	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
	
	# Build the new credential object
	$Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
	Write-Output $Credential
}

<#
.SYNOPSIS
Visual countdown timer

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
watch-countdown -seconds 30

#>
function watch-countdown {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[int]$seconds,
	[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
	[ValidateNotNullOrEmpty()]
	[string]$message = "Pausing script..."
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$toalSeconds = $seconds
		$length = $toalSeconds / 100
		while ($toalSeconds -gt 0)
		{
			$min = [int](([string]($toalSeconds/60)).split('.')[0])
			$text = " " + $min + " minutes " + ($toalSeconds % 60) + " seconds left"
			Write-Progress "$message" -status $text -perc ($toalSeconds/$length)
			start-sleep -s 1
			$toalSeconds--
		}
		
		
	}
	END
	{

	}	

}


<#
.SYNOPSIS
Gets LUN info based on NTFS label name
Version 1.00

.DESCRIPTION
Will look for volume and partition info and output information needed by Add-PartitionAccessPath and Remove-PartitionAccessPath


.PARAMETER  NtfsLabel



.EXAMPLE
Get-VolumeMountInfo -ntfslabel SERVERNAME-DATAVOL1

#>

function get-VolumeMountInfo
{
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ntfsLabel
	)
	
	BEGIN
	{
		
	}
	PROCESS
	{
		try
		{
			$vol = get-volume -FileSystemLabel $ntfsLabel -ErrorAction:stop
		}
		catch
		{
			write-error "Error getting volume info for $ntfsLabel"
		}
		
		
		try
		{
			$partition = get-partition -Volume $vol -ErrorAction:stop
		}
		catch
		{
			write-error "Error getting partition info for $ntfsLabel"
		}
		
		
		$obj = @()
		$obj = "" | select-object NtfsLabel, AccessPath, DiskID, Offset, isMounted
		$obj.NtfsLabel = $ntfsLabel
		$obj.DiskID = $partition.diskid
		$obj.Offset = $partition.offset
		
		
		# There are one or more access paths, at the minimum there is a GUID access path
		foreach ($Accesspath in $partition.AccessPaths)
		{
			if ($Accesspath -match '(\w:).*') # Looking for the access path that has the drive letter, not the GUID
			{
				$obj.AccessPath = $AccessPath
				$obj.ismounted = [boolean]$true
			}
		}
		
		if ($obj.isMounted -ne $true)
		{
			$obj.AccessPath = 'NOT MOUNTED'
		}
		
		write-output $obj
		
	}
	
	END
	{
		
	}
	
}

function Export-ExcelWorksheet
{
  <#
  .SYNOPSIS
 Converts an Excel worksheet to CSV output object
  .DESCRIPTION
  
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
	import-module csgp-common -force
	remove-variable result -erroraction:silentlycontinue
	$path = 'http://projectportal/GoldRush/Shared Documents/APTS-LAX-AWS-Server-List.xlsx'
	$worksheet = 'masterinventory'
	$result = Export-ExcelWorksheet -path $path -worksheet $worksheet
 
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$path,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$worksheet
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$tmpCsv = [System.IO.Path]::GetTempFileName()
		
		$objExcel = New-Object -ComObject Excel.Application
		$objExcel.Visible = $False
		$objExcel.DisplayAlerts = $False
		$WorkBookObj = $objExcel.Workbooks.Open($path)
		$WorkSheetObj = $WorkBookObj.sheets.item("$worksheet")
		$xlCSV = 6
		$WorkBookObj.SaveAs($tmpCsv, $xlCSV)
		$ObjExcel.Workbooks.Close()
		$ObjExcel.Application.Quit()
		$objExcel.quit()
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($objExcel) | Out-Null   # do not remove out-null it will add unwanted output to the write-output statement
		sleep 1
		[System.GC]::Collect() # all this stuff above still does not get rid of the excel.exe processes.... may have to do a before/after filterd by username and then kill the process.
		
		$csv = Import-Csv -path $tmpCsv
		
		Remove-Item -Path $tmpCsv
		
		Write-Output $csv
		
	}
	
	End
	{
		
	}
}
