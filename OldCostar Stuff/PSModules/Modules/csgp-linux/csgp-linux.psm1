
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"	# default to showing all verbose info


<#
.SYNOPSIS
Adds a RedHat server that has Power Broker Identify Services (PBIS) to a AD domain
Version 1.00

.DESCRIPTION
Reads in a credential previously stored via Windows Data Protection API and joins the Linux server to the domain.  

.PARAMETER user
This user must exist on the Linux server as a local account.  We will ssh to the server using this account.  
This account name will also be used as the domain join account for AD

.EXAMPLE
$DomainAddResult = Add-PbisLinuxToDomain -credfile $credFileFullName -computer $newComputerName -domain us.costar.local -user $LinuxDomainJoinUser

#>
function Add-PbisLinuxToDomain
{
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$domain,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$username,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		$VerbosePreference = "SilentlyContinue"
		$session = New-SSHSession -computer  $computer -Credential $cred -AcceptKey:$true
		$VerbosePreference = "Continue"
		$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
		$LinuxjoinCli = "sudo /opt/pbis/bin/domainjoin-cli join $domain $username@$domain $($cred.GetNetworkCredential().password)"
		
		sleep 1
		$trash = $Stream.Read()	# get rid of any pending output from terminal
		
		# Renci.SshNet does not support sudo when using invoke-sshcommand, need to use shellstream instead
		$stream.write("$LinuxjoinCli`n")
		
		# Have to wait until the output shows SUCCESS, lowering this too much will cause this command to run (seen in /var/log/secure) but it will not work properly and drive you fucking crazy
		# fails sometimes at 20 seconds...
		# have seen this fail at 30 seconds as well...
		watch-countdown -seconds 120 -message "Joining $computer to $domain..."
		$JoinOutput = (($stream.Read()).split("`n")).trim()   # No error checking on this yet
		# Write-Output "$JoinOutput" > "$env:USERPROFILE\documents\out.txt"
		
		IF ($JoinOutput -contains 'SUCCESS')
		{
			$domainJoinOk = [boolean]$true
		}
		else
		{
			$domainJoinOk = [boolean]$false
			Write-Verbose "$JoinOutput"	# remove this after it's stable.   Will output clear text passwords.
		}
		
		Remove-Variable -Name cred  | Out-Null
		Remove-Variable -Name JoinOutput | Out-Null
		remove-sshsession -sshsession $session | Out-Null
		
		Write-Output $domainJoinOk
	}
	
	End
	{
		
	}
}


<#
.SYNOPSIS
Subscribes a RedHat server to the Red Hat Network
Version 1.00

.DESCRIPTION

.SERVICELEVEL
'self-support' for dev and tst
'standard' for production

.EXAMPLE
$rhnSubscribeResult = New-RedHatSubscription -computer $newComputerName -servicelevel $servicelevel -cred $sshCred

#>

function New-RedHatSubscription
{
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('self-support', 'standard', ignorecase = $False)]
		[string]$servicelevel,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
	
	begin
	{
		$rhnUser = 'costarsystemsteam'
		$rhnPassword = 'n)i/8gUQF|D#'
	}
	
	process
	{
		$VerbosePreference = "SilentlyContinue"
		$session = New-SSHSession -computer $computer -Credential $cred -AcceptKey:$true
		$VerbosePreference = "Continue"
		$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
		$sshCli = "sudo /usr/bin/subscription-manager register --username costarsystemsteam --password `'$rhnPassword`' --servicelevel=$servicelevel --auto-attach"
		
		sleep 1
		$trash = $Stream.Read()	# get rid of any pending output from terminal
		
		# Renci.SshNet does not support sudo when using invoke-sshcommand, need to use shellstream instead
		$stream.write("$sshCli`n")
		
		# Registration takes about 9 seconds, we'll wait for 20
		watch-countdown -seconds 20 -message "Subscribing $computer to the RedHat Network..."
		$sshCliOutput = (($stream.Read()).split("`n")).trim()   # No error checking on this yet
		
		
		foreach ($line in $sshCliOutput)
		{
			IF ($line -like  "*The system has been registered*")
			{
				$rhnSubscribed = [boolean]$true
				break
			}
			else
			{
				continue # keep trying to match the line
			}
		}
		
		if (! (Test-Path variable:\rhnSubscribed) )
		{
			$rhnSubscribed = [boolean]$false
		}
		
		# Write-Output $rhnSubscribed
		
		remove-sshsession -sshsession $session | Out-Null
		
		$subscriptionStatus = Get-RedHatSubscription -computer $computer -cred $Cred
		
		Remove-Variable -Name cred | Out-Null
		Remove-Variable -Name sshCliOutput | Out-Null
		
		Write-Output $subscriptionStatus
	}
	
	End
	{
		
	}
}

<#
.SYNOPSIS
Gets RedHat server subscription status
Version 1.00

.DESCRIPTION


.EXAMPLE
$rhnSubscribeResult = Get-RedHatSubscription -computer $newComputerName  -cred $sshCred

#>
function Get-RedHatSubscription
{
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
	
	begin
	{
		Set-StrictMode -Version 2
	}
	
	process
	{
		$VerbosePreference = "SilentlyContinue"	# the New-SSHSession outputs authentication information even when using -verbose:$false
		$session = New-SSHSession -computer $computer -Credential $cred -AcceptKey:$true 
		$VerbosePreference = "Continue"
		$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
		$sshCli = "sudo /usr/bin/subscription-manager status"
		
		sleep 1
		$trash = $Stream.Read()	# get rid of any pending output from terminal
		
		# Renci.SshNet does not support sudo when using invoke-sshcommand, need to use shellstream instead
		$stream.write("$sshCli`n")
		
		$span = New-TimeSpan -Seconds 10
		$obj = @()
		$obj = "" | Select-Object Computer, RegistrationStatus, UUID
		
		try
		{
			$sshCliOutput = $stream.Expect("Overall Status:", $span)
			# will throw this error if expect not found:
			# You cannot call a method on a null-valued expression
			
			$sshCliOutput = ($sshCliOutput).split("`n").trim()   # No error checking on this yet
			
			
			
			:outer foreach ($row in $sshCliOutput)
			{
				if ($row -like "*Overall Status: Unknown*")
				{
					$registrationStatus = "Not registered"
					$obj.computer = $computer
					$obj.registrationstatus = $registrationStatus
				}
				elseif ($row -like "*Overall Status: Insufficient*")
				{
					# we might see this when a the subscription is trying to map to a VMHost
					# "Guest has not been reported on any host and is using a temporary unmapped guest subscription."
					$registrationStatus = "Insufficient"
					$obj.computer = $computer
					$obj.registrationstatus = $registrationStatus
				}
				elseif ($row -like "*Overall Status: Invalid*")
				{
					# we might see this error message:
					# - Not supported by a valid subscription
					$registrationStatus = "Invalid"
					$obj.computer = $computer
					$obj.registrationstatus = $registrationStatus
				}
				elseif ($row -like "*Overall Status: Current*")
				{
					$registrationStatus = "Registered"
					$obj.computer = $computer
					$obj.registrationstatus = $registrationStatus
					
					# System is registered, let's get the system.uuid (only present when registered), matches what we see in RHN portal
					$identityCli = "sudo /usr/bin/subscription-manager identity"
					$stream.write("$identityCli`n")
					#$identityCliOutput = $stream.Expect('system.uuid: ', $span)	# Not reliable vs sleep... :-(
					sleep 3
					$identityCliOutput = $stream.Read()
					$identityCliOutput = ($identityCliOutput).split("`n").trim()
					
					
					foreach ($identity in $identityCliOutput)
					{
						if ($identity -match '(^system identity: )(.*)')
						{
							$identityUuid = $matches[2]
							# Write-Output $matches
							
							$obj.uuid = $identityUuid
							break outer
						}
					}
					
				}
			}
		}
		catch
		{
			$obj.computer = $computer
			$obj.RegistrationStatus = "Error running subscription-manager status"
		}
		
		Write-Output $obj
		
		Remove-Variable -Name cred | Out-Null
		Remove-Variable -Name sshCliOutput | Out-Null
		remove-sshsession -sshsession $session | Out-Null
		
		
	}
	
	End
	{
		
	}
}

<#
.SYNOPSIS
Logs into a Linux server and disables a user account
Version 1.00

.DESCRIPTION
Reads in a credential previously stored via Windows Data Protection API and logs in and disables an account

.PARAMETER user


.EXAMPLE
$UserDisableResult = Disable-LinuxUser -cred $sshCred -computer $Computer -user $LinuxDomainJoinUser

#>
function Disable-LinuxUser
{
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$username,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		$VerbosePreference = "SilentlyContinue"
		$session = New-SSHSession -computer  $computer -Credential $cred -AcceptKey:$true
		$VerbosePreference = "Continue"
		$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
		
		sleep 1
		$trash = $Stream.Read()	# get rid of any pending output from terminal
		
		# Expire the account so nobody can use it
		$ExpireCli = "sudo /usr/sbin/usermod --expiredate 1970-01-01 $username"
		$stream.write("$ExpireCli`n")
		Start-Sleep -Seconds 1
		$ExpireOutput = (($stream.Read()).split("`n")).trim()
		
		
		Remove-Variable -Name cred | Out-Null
		Remove-Variable -Name ExpireOutput | Out-Null
		remove-sshsession -sshsession $session | Out-Null
		
		
	}
	
	End
	{
		
	}
}


<#
.SYNOPSIS
Runs a command against a linux server
Version 1.00

.DESCRIPTION


.EXAMPLE
$rhnSubscribeResult = Get-RedHatSubscription -computer $Computer  -cred $sshCred

#>
function invoke-LinuxSshCommand
{
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$cli,
		[parameter(Mandatory = $False, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[int]$wait	= 10 # number of seconds to block waiting for $stream.expect() to match ]$ prompt
		
	)
	
	begin
	{
		Set-StrictMode -Version 2
	}
	
	process
	{
		
		
		try
		{
			
			$VerbosePreference = "SilentlyContinue"	# the New-SSHSession outputs authentication information even when using -verbose:$false
			$session = New-SSHSession -computer $computer -Credential $cred -AcceptKey:$true
			$VerbosePreference = "Continue"
			$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
			
			# wait this long when using expect()
			$span = New-TimeSpan -Seconds $wait
		}
		catch
		{
			Write-Warning "Unable to connect to $computer $_"
			continue
		}

		try {
			$VerbosePreference = "SilentlyContinue" # the New-SSHSession outputs authentication information even when using -verbose:$false, this will stop that for the one command
			$session = New-SSHSession -computer $computer -Credential $cred -AcceptKey:$true
			$VerbosePreference = "Continue"	
			$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
			
			sleep 1
			$trash = $Stream.Read()	# get rid of any pending output from terminal
			
			# Send the command
			$stream.write("$cli`n")
			start-sleep 2	# we seem to need to sleep for some period of time or else the $stream commands below run before the $cli command has finished executing
			
			$cliOutputPrompt = $stream.Expect(']$', $span)	# Wait for the user prompt to come back, capture it and ignore
			
			$cliOutput = $stream.read()	# the command output, will also include the string from $cli
			
			$VerbosePreference = "SilentlyContinue"
			remove-sshsession -sshsession $session | Out-Null
			$VerbosePreference = "Continue"
			
			$cliArray = (($cliOutput).split("`n")).trim()	# get output into array format
			
			$cliArray = $cliarray[1..($cliarray.length - 1)]  # remove first item which is the echoed $cli
			$cliArray = $cliarray[0..($cliarray.length - 2)]  # remove last item in the array which is the prompt
			
		}
		catch
		{
			Write-Warning "Failed to execute cli on $computer"
			$VerbosePreference = "SilentlyContinue"
			remove-sshsession -sshsession $session
			$VerbosePreference = "Continue"
		}
		
		Write-Output $cliArray
		
		Remove-Variable -Name cred | Out-Null
		Remove-Variable -Name cli | Out-Null
		remove-sshsession -sshsession $session | Out-Null
		
		
	}
	
	End
	{
		
	}
}

<#
.SYNOPSIS
Tests to see if we can ssh into the server
Version 1.00

.DESCRIPTION


.EXAMPLE
$sshTestResult = Test-ConnectionLinux -computer $ComputerName  -cred $sshCred

#>
function Test-ConnectionLinux
{
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	param
	(
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$cred = $(Get-Credential),
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
	
	begin
	{
		Set-StrictMode -Version 2
	}
	
	process
	{
		$VerbosePreference = "SilentlyContinue"	# the New-SSHSession outputs authentication information even when using -verbose:$false
		$session = New-SSHSession -computer $computer -Credential $cred -AcceptKey:$true
		$VerbosePreference = "Continue"
		$stream = $session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
		$sshCli = "uname -s"
		
		sleep 1
		$trash = $Stream.Read()	# get rid of any pending output from terminal
				
		# Renci.SshNet does not support sudo when using invoke-sshcommand, need to use shellstream instead
		$stream.write("$sshCli`n")
		
		$span = New-TimeSpan -Seconds 10
		$obj = @()
		$obj = "" | Select-Object Computer, KernelName, Success
		
		try
		{
			$sshCliOutput = $stream.Expect("Linux", $span)
			# will throw this error if expect not found:
			# You cannot call a method on a null-valued expression
			
			$sshCliOutput = ($sshCliOutput).split("`n").trim()   # No error checking on this yet
			
			$obj.Computer = $computer
			$obj.KernelName = $sshCliOutput[1]
			$obj.Success = [boolean]$true
		}
		catch
		{
			$obj.computer = $computer
			$obj.KernelName = $_
			$obj.Success = [boolean]$false
		}
		
		Write-Output $obj
		
		Remove-Variable -Name cred | Out-Null
		Remove-Variable -Name sshCliOutput | Out-Null
		remove-sshsession -sshsession $session | Out-Null
		
		
	}
	
	End
	{
		
	}
}

