<#
	.SYNOPSIS
		This function checks for the SecuredCLIXMLEncrypted.key in your user directory

	.DESCRIPTION
		SecuredCLIXMLEncrypted.key indicates that you have attempted to setup
		security with naviseccli.exe using the -AddUserSecurity feature.
		
	.EXAMPLE
	Get-NaviUserSecurity
		
#>
function Get-NaviUserSecurity {

	[CmdletBinding()]
	param(
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$homeDrive = $env:HOMEDRIVE,
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$homePath = $env:HOMEPATH
	)
	
	$keyFile = "$homeDrive\$homePath\SecuredCLIXMLEncrypted.key"
	
	If (! (Test-Path $keyFile) )	{
		Write-Error "We can't seem to find your Naviseccli keyfile. Default location is at $keyfile.`n`nUse naviseccli -addusersecurity -scope 2 -user $env:username`n"
	} else {
		write-verbose "Naviseccli UserSecurity file seems intact"
	}

}

<#
.SYNOPSIS
new-naviCommand allows you to run a naviseccli.exe command and capture its output


.DESCRIPTION

.EXAMPLE
new-naviCommand -spAddress visan101-spb -navicmd 'analyzer -archive -list'

#>
function new-naviCommand {

	[CmdletBinding()]
	param(
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$cmd = 'C:\Program Files (x86)\EMC\Navisphere CLI\naviseccli.exe',
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$spAddress,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$naviCmd, # $naviCmd will have a uniqe naviseccli CMD
		[parameter(Mandatory=$FALSE)]
		[ValidateNotNullOrEmpty()]
		[switch]$echo
		)
	
	BEGIN
	{
		Get-NaviUserSecurity	# check to see if there is a Naviseccli keyfile
	}
	
	PROCESS
	{
		$ps = new-object System.Diagnostics.Process 
		$ps.StartInfo.Filename = $cmd 
		$ps.StartInfo.Arguments = " -address $spAddress $naviCmd"
		if ($echo)	{
			Write-host "$($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)" -ForegroundColor Green
		}
		$ps.StartInfo.RedirectStandardOutput = $True 
		$ps.StartInfo.UseShellExecute = $false
		$ps.StartInfo.CreateNoWindow = $true
		$ps.start() | Out-Null
		[string] $result = $ps.StandardOutput.ReadToEnd();
		$result = $result.trim()
		write-output $result

	}
	
	END
	{
	
	}
}