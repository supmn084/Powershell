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
			[string]$smtpBody,
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
cls
#$reportResults.snapInfo | ConvertTo-Html  -head $a -Body $htmlbody | Out-File "c:\temp\Test.htm"
#send-Mail -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com,mrbenconrad@gmail.com" -smtpSubject "this is my subject"  -smtpBody $(Get-Content "c:\temp\test.htm") 
#send-Mail -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com" -smtpSubject "Unauthorized user found in $groupNeedingUserRemoval"  -smtpBody "$user is NOT allowed in $monitoredGroupName, removing..." 