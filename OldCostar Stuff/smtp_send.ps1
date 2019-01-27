function smtp_send 	{
[cmdletBinding()]
		param(
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpTo,
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpSubject,
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpBody,
			[Parameter(Mandatory=$False,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpAttach=$('empty'),
			[Parameter(Mandatory=$True,ValueFromPipeline=$false)] # Required and accepts pipeline input
			[string]$smtpServer
		)
	#
	# smtp_send: Send smtp mail with optional attachment.
	#
	#	You can leave out -smtpAttach in the call and the script will not send an attachement
	#
	# ex: smtp_send -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com" -smtpSubject "this is my subject" -smtpBody "this is my body"  -smtpAttach "h:\servers.txt"
	# ex: smtp_send -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com" -smtpSubject "this is my subject" -smtpBody "this is my body"  

	

	$msg = new-object Net.Mail.MailMessage
	$smtp = new-object Net.Mail.SmtpClient($smtpServer)
	

	$msg.From = $env:computername + $smtpFromDomain
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
#smtp_send -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com,mrbenconrad@gmail.com" -smtpSubject "this is my subject"  -smtpBody $(Get-Content "c:\temp\test.htm") 
#smtp_send -smtpServer "dcrelay1.costar.com" -smtpTo "bconrad@costar.com" -smtpSubject "Unauthorized user found in $groupNeedingUserRemoval"  -smtpBody "$user is NOT allowed in $monitoredGroupName, removing..." 