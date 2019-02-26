#REQUIRES -Version 2.0

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function Get-fcaliasName
{
  <#
  .SYNOPSIS
  Will show all fcalias and associated VSAN on a nexus switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$switch = 'switch_name_or_IP'
	$credential = get-credential

	connect-switch -switch $switch -cred $credential
	$alises = Get-fcaliasName
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
  .PARAMETER computername
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$search	# Search for a substring in the fcalias
	)
	
	begin
	{
		$hostname = (get-hostname).hostname
		
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; show fcalias | inc fcalias`n")
		start-sleep -milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD: $line"
			# 'fcalias name ve04scluprd001b_vhba1 vsan 10'
			if ($line -match '(^fcalias name )(?<fcalias>\S+)( vsan )(?<vsan>\d+)')
			{
				$obj = @()
				$obj = "" | Select-Object Hostname, FcAlias, vsan
				$obj.hostname = $hostname
				$obj.fcalias = $matches.fcalias
				$obj.vsan = [int]$matches.vsan
				if ($search)
				{
					if ($matches.fcalias -like "*$search*")
					{
						Write-Output $obj
					}
				}
				else
				{
					Write-Output $obj
					Write-Verbose "Matched fcalias: $line"
				}
			}
		}
	}
	
	End
	{
		
	}
}

function Get-fcalias
{
  <#
  .SYNOPSIS
  Will show all fcalias on a nexus switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	$alises = get-fcaliasname |  Get-fcalias
	disconnect-switch -sshsession $sshSession

  .EXAMPLE
  
	$alises = get-fcaliasname -fcalias "blah_vhba1"
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$fcalias
	)
	
	begin
	{		
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		Write-Verbose "My Alias: $fcalias"
		$sshStream.write("term length 0 ; show fcalias name $fcalias`n")
		start-sleep -Milliseconds 300
		# take output and convert to array
		$output = (($sshStream.Read()).split("`n")).trim()
		
		$obj = "" | Select-Object FcAlias, pwwn, vsan
		[array]$pwwn = @()
		
		foreach ($line in $output)
		{
			Write-Verbose "Get-fcalias: $line"
			# 'fcalias name ve04scluprd001c_vhba1 vsan 10'
			if ($line -match '(^fcalias name )(?<fcalias>\S+)( vsan )(?<vsan>\d+)')
			{
				$obj.fcalias = $matches.fcalias
				$obj.vsan = [int]$matches.vsan
			}
			
			#'  pwwn 20:00:00:25:b5:5a:00:6d'
			elseif ($line -match '(\s*\w+\s)(?<pwwn>\w\w:\w\w:\w\w:\w\w:\w\w:\w\w:\w\w:\w\w)')
			{
				$pwwn += $matches.pwwn
			}
			
		}
		
		$obj.pwwn = $pwwn
		Write-Output $obj
		
	}
	
	End
	{
		
	}
}

function Get-FcaliasByPwwn
{
  <#
  .SYNOPSIS
  Will show all zones that a pwwn is a member of
  .DESCRIPTION
  This function does not suppport having the same pwwn on multiple fcalias
	Will throw a terminating error if pwwn has multiple aliases
	
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	Get-FcaliasByPwwn -pwwn 20:00:00:25:b5:5a:00:7d 
	disconnect-switch -sshsession $sshSession
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string[]]$pwwn
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0`n")
		$sshStream.write("show zone member pwwn $pwwn`n")
		start-sleep -Milliseconds 300
		# take output and convert to array
		$output = (($sshStream.Read()).split("`n")).trim()
		
		$obj = "" | Select-Object pwwn, fcalias, zone, vsan
		[array]$zone = @()
		[array]$aliasCounter = @()
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD: $line"
			
			# show zone member pwwn $pwwn command output looks like:
			# pwwn 20:00:00:25:b5:5a:00:5f vsan 10
			# 	fcalias ap04sqltprd582_vhba1
			# 		zone ap04sqltprd582_vhba1-lasan100_spa0
			# 		zone ap04sqltprd582_vhba1-lasan100_spb1
			
			
			if ($line -match '(pwwn\s)(?<myPwwn>.*)(\svsan\s)(?<myVsan>\d+)')
			{
				#$aliasCounter += $matches.fcalias
				$obj.pwwn = $matches.myPwwn
				write-verbose "Matched pwwn $($matches.myPwwn)"
				$obj.vsan = $matches.myVsan
				write-verbose "Matched vsan $($matches.myVsan)"
			}
			
			if ($line -match '(^\s*fcalias\s)(?<fcalias>\S+)')
			{
				$aliasCounter += $matches.fcalias
				$obj.fcalias = $matches.fcalias
				write-verbose "Matched fcalias $($matches.fcalias)"
			}
			
			#'  pwwn 20:00:00:25:b5:5a:00:6d'
			elseif ($line -match '(^\s*zone\s)(?<zone>\S+)')
			{
				$zone += $matches.zone
				write-verbose "Matched zone $($matches.zone)"
			}
			
		}
		
		# If the pwwn has more than one fcalias throw error
		# we need to stick to the standard single pwwn to single fcalias
		if ($aliasCounter.count -gt 1)
		{
			Write-Error "Safety check: Multiple alaises bound to pwwn $pwwn"
			break
		}
		
		#$obj.pwwn = $pwwn
		$obj.zone = $zone
		Write-Output $obj
		
	}
	
	End
	{
		
	}
}

function Get-zone
{
  <#
  .SYNOPSIS
  Will show all zone names on a nexus switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	$alises = get-zone
	disconnect-switch -sshsession $sshSession
	
	
	
	
  .EXAMPLE
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$search	# Search for a substring in the zone name
	)
	
	begin
	{
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; show zone`n")
		start-sleep -Milliseconds 300
		# take output and convert to array
		$output = (($sshStream.Read()).split("`n")).trim()
		
		foreach ($line in $output)
		{
			
			$obj = @()
			$obj = "" | Select-Object Zone, vsan
			
			# 'zone name ve04scluprd001c_vhba1-lnsan02_sp0a vsan 10'
			if ($line -match '(^zone name )(?<zone>\S+)( vsan )(?<vsan>\d+)')
			{
				$obj.zone = $matches.zone
				$obj.vsan = [int]$matches.vsan
				if ($search)
				{
					if ($matches.zone -like "*$search*")
					{
						Write-Output $obj
					}
				}
				else
				{
					Write-Output $obj
				}
			}
		}
	}
	
	End
	{
	}
	
}

function Get-Pwwn
{
  <#
  .SYNOPSIS
  Will show all pwwn and fcalias
  .DESCRIPTION
  	
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	get-pwwn
	disconnect-switch -sshsession $sshSession

  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0`n")
		$sshStream.write("show fcalias`n")
		start-sleep -Milliseconds 300
		# take output and convert to array
		$output = (($sshStream.Read()).split("`n")).trim()
		
		$obj = "" | Select-Object pwwn, fcalias,vsan
		[array]$zone = @()
		[array]$pwwn = @()
		$pwwnFoundInString = $false
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD: $line"
			
			# command output looks like
			#fcalias name ap04scluprd011b_vhba1 vsan 10
			#pwwn 20:00:00:25:b5:5a:00:67
			
			#fcalias name lasan100_spb1 vsan 10
			#pwwn 50:06:01:69:08:60:32:cc
			
			
			
			if ($line -match '(fcalias\sname\s)(?<fcalias>\S+)(\svsan\s)(?<myVsan>\d+)')
			{
				
				# if $pwwnFoundInString -eq $true we are now in the next itteration of 'fcalias name' line
				#  this means we have been through the first 'fcalias name' itteration
				# and have also seen one or more of the 'pwwn xx' lines
				# Add those 'pwwn' lines from the last itteration to the fcalias found
				# in the last itteration and output.  then proceed with the second itteration
				# where we will find more fcalias and pwwn
				if ($pwwnFoundInString -eq $true)
				{
					$obj.pwwn = $pwwn
					# first itteration done, write to output
					Write-Output $obj
					$pwwnFoundInString = $false
					$pwwn = @()
				}
				$obj.fcalias = $matches.fcalias
				write-verbose "Matched fcalias $($matches.fcalias)"
				$obj.vsan = [int]$matches.myVsan
				write-verbose "Matched vsan $($matches.myVsan)"
				continue
			}
			
			if ($line -match '(.*)(?<MyPwwn>\S\S:\S\S:\S\S:\S\S:\S\S:\S\S:\S\S:\S\S)')
			{
				# Add all pwwn lines found after the 'fcalias name' line
				$pwwn += $matches.myPwwn
				$pwwnFoundInString = $true
				write-verbose "Matched pwwn $($matches.myPwwn)"
				continue
			}
		
			
	
		}
	}
	
	End
	{
		
	}
}

function Get-ZoneSet
{
  <#
  .SYNOPSIS
  Will show the active zoneset
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$switch = 'switch_name_or_IP'
	$credential = get-credential

	
	connect-switch -switch $switch -cred $credential
	get-zoneset
	disconnect-switch -sshsession $sshSession
	

  .EXAMPLE
  
  .PARAMETER computername
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
	)
	
	begin
	{
		
		
	}
	
	process
	{
		
		$obj = "" | Select-Object hostname,zoneset, vsan
		
		$hostname = (get-switch).hostname
		Write-Verbose "hostname is: $hostname"
		$obj.hostname = $hostname
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0`n")
		$sshStream.write("show zoneset active`n")
		$sshStream.write("end`n")
		start-sleep -milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		
		
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD: $line"
			
			# zoneset name zoneset_vsan10 vsan 10
			
			if ($line -match '(^zoneset name\s)(?<zoneset>\S+)(\svsan\s)(?<vsan>\d+)' )
			{
				Write-Verbose "Found zoneset $($matches.zoneset)"
				$obj.zoneset = $matches.zoneset
				$obj.vsan = $matches.vsan
				Write-Output $obj
				break
				
			}
		}
	}
	
	End
	{
		
	}
}

function Get-ZoneSetStatus
{
  <#
  .SYNOPSIS
  Checks the status of the active zoneset
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	get-zonesetstatus
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan
	)
	
	begin
	{
	}
	
	process
	{
		$obj = "" | Select-Object Hostname, Status,ZoneSet, Zones
		
		$hostname = (get-switch).hostname
		Write-Verbose "hostname is: $hostname"
		$obj.hostname = $hostname
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0`n")
		$sshStream.write("show zone status vsan $vsan | inc Status:|Name:`n")
		#$sshStream.write("end`n")
		start-sleep -Milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD:$line"
			
			#  Name: zoneset_vsan10  Zonesets:1  Zones:108
			if ($line -match '(^Name:\s+)(?<zonesetname>.*\s+)Zonesets:\d+\s+Zones:(?<numZones>\d+)' )
			{
				$obj.zones = $matches.numZones
				$obj.zoneset = $matches.zonesetname
			}
			
			#Status: Activation completed at 02:35:02 UTC Mar 19 2015
			if ($line -match '^Status: (?<activationStatus>.*)' )
			{
				$obj.status = $matches.activationStatus
			}
		}
		
		Write-Output $obj
		
	}
	
	End
	{
		
	}
}

function get-switch
{
  <#
  .SYNOPSIS
  gets some basic info about the switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	get-switch
	disconnect-switch -sshsession $sshSession

  .EXAMPLE
    
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		
	)
	
	begin
	{
	}
	
	process
	{
		
		$obj = "" | Select-Object Hostname,Version,Uptime
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0`n")
		$sshStream.write("show ver`n")
		#$sshStream.write("end`n")
		start-sleep -Milliseconds 1000	# 300 causes some funky issues
		$output = (($sshStream.Read()).split("`n")).trim()
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD:$line"
			if ($line -match '(^Device name:\s)(?<hostname>\S+)' )
			{
				Write-Verbose "Found hostname: $($matches.hostname)"
				$obj.hostname = $matches.hostname
			}
			
			if ($line -match '(^System version:\s)(?<version>\S+)')
			{
				Write-Verbose "Found version: $($matches.version)"
				$obj.version = $matches.version
			}
			
			if ($line -match '(^Kernel uptime is )(?<uptime>.+)' )
			{
				Write-Verbose "Found uptime: $($matches.uptime)"
				$obj.uptime = $matches.uptime
			}
		}
		
		Write-Output $obj
		
	}
	
	End
	{
		
	}
}

function get-hostname
{
  <#
  .SYNOPSIS
  gets some basic info about the switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	get-hostname
	disconnect-switch -sshsession $sshSession

  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		
	)
	
	begin
	{
	}
	
	process
	{
		$obj = "" | Select-Object Hostname
		$output = ""
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; show hostname`n")
		
		start-sleep -Milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		Write-Verbose "$output"
		
		$split = $output -split '\s+'
		$obj.hostname = $split[6]
		
		Write-Output $obj
		
	}
	
	End
	{
		
	}
}

function new-fcalias
{
  <#
  .SYNOPSIS
  creates a new fcalias on NXOS
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	new-fcalias -fcalias bentest2_vhba1 -vsan 10 -pwwn 99:99:99:99:99:99:99:01
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$fcalias,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$pwwn
		
	)
	
	begin
	{
	}
	
	process
	{
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")	# maintain exact spacing
		$sshStream.write("fcalias name $fcalias vsan $vsan`n")
		$sshStream.write("member pwwn $pwwn`n")
		$sshStream.write("end`n")
		sleep -Milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		
		Get-fcalias -fcalias $fcalias
	}
	
	End
	{
		
	}
}

function new-zone
{
  <#
  .SYNOPSIS
  creates a new fcalias on NXOS
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	new-zone -fcalias bentest1_vhba1 -sanalias lasan100_spb1 -vsan 10
	disconnect-switch -sshsession $sshSession

  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$fcalias,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$sanAlias
		
	)
	
	begin
	{
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")
		$sshStream.write("zone name $fcalias-$sanalias vsan $vsan`n")
		$sshStream.write("member fcalias $fcalias`n")
		$sshStream.write("member fcalias $sanalias`n")
		$sshStream.write("end`n")
		sleep -Milliseconds 300
		$output = (($sshStream.Read()).split("`n")).trim()
		
		Get-zone | ? { $_.zone -eq "$fcalias-$sanalias" }
	}
	
	End
	{
		
	}
}

function rename-fcalias
{
  <#
  .SYNOPSIS
  Renames an existing fc alias
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	rename-fcalias -oldHostAlias bentest1_vhba1 -newHostAlias bentestx_vhba1 -vsan 10
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$oldHostAlias,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$newHostAlias,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan
		
	)
	
	begin
	{
	}
	
	process
	{
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")
		$sshStream.write("fcalias rename $oldHostAlias $newHostAlias vsan $vsan`n")
		$sshStream.write("exit`n")
		
		Get-fcalias -fcalias $newHostAlias
	}
	
	End
	{
		
	}
}

function rename-zone
{
  <#
  .SYNOPSIS
  renames a fc zone
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	new-fcalias -fcalias bentest2_vhba1 -vsan 10 -pwwn 99:99:99:99:99:99:99:01
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$oldZone,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$newZone,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan	
	)
	
	begin
	{
	}
	
	process
	{
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")
		$sshStream.write("zone rename $oldZone $newZone vsan $vsan`n")
		$sshStream.write("exit`n")
		
		# Get-zone -fcalias $newHostAlias
	}
	
	End
	{
		
	}
}

function remove-fcalias
{
  <#
  .SYNOPSIS
  Removes a FC alias 
  .DESCRIPTION
  This script will remove a FC alias from a Nexus switch.  There is a safety check
	to make sure the EMC VNX WWPN is not removed by mistake
	
  You may also use this cmdlet to remove an fclias from a zone
	
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	remove-fcalias -fcalias bentest2_vhba1 -vsan 10 -confirm:$false
	disconnect-switch -sshsession $sshSession
	
	
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	# WARNING!!!! 
	# Using override will allow you to remove EMC VNX aliases
	remove-fcalias -fcalias mysan_spa0 -vsan 10 -confirm:$false -override
	# WARNING!!!!
	disconnect-switch -sshsession $sshSession
	
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$fcalias,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$vsan,
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[switch]$override
	
	)
	
	begin
	{

	}
	
	process
	{
		$fcAliasisEmc = $false
		$emcPwwn = '50:06:01'
		
		if ($PSCmdlet.ShouldProcess($fcalias))
		{
			
			# get the fcalias so we can look at the pwwn to check for EMC pwwn
			$fcAliasObj = Get-fcalias -fcalias $fcalias
			
			foreach ($alias in $fcAliasObj)
			{
				
				# check to see if we have an EMC pwwn
				if ($alias.pwwn -like "$emcPwwn*")
				{
					$fcAliasisEmc = $true
					$emcPwwn = $alias.pwwn
					Write-Verbose "EMC PWWN: $($alias.pwwn)"
				}
			}
			
			# if EMC pwwn and not -override throw a warning and break out of the process block
			if ( ($fcAliasisEmc -eq $true) -and (! $override) )
			{
				Write-warning "You are attempting to delete an EMC PWWN ($emcPwwn), use -override to ignore"
				break
			}
			
			# a normal pwwn (not emc) or -override (because it is a EMC pwwn)
			if (($fcAliasisEmc -eq $false) -or ($override))
			{
				$trash = $sshStream.Read()	# get rid of any pending output
				
				$sshStream.write("term length 0 ; config t`n")
				$sshStream.write("no fcalias name $fcalias vsan $vsan`n")
				$sshStream.write("exit`n")
				start-sleep -Milliseconds 300
				$output = (($sshStream.Read()).split("`n")).trim()
			}
		}
	}
	
	End
	{
		
	}
}

function remove-zone
{
  <#
  .SYNOPSIS
  Removes a FC zone
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	remove-zone -zone bentest1_vhba1-lasan100_spa0 -vsan 10
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$zone,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[int]$vsan
	)
	
	begin
	{
	}
	
	process
	{
		
		if ($PSCmdlet.ShouldProcess($zone))
		{
			$trash = $sshStream.Read()	# get rid of any pending output
			
			$sshStream.write("term length 0 ; config t`n")
			$sshStream.write("no zone name $zone vsan $vsan`n")
			$sshStream.write("exit`n")
			start-sleep -Milliseconds 300
			$output = (($sshStream.Read()).split("`n")).trim()
			
		}
		
	}
	
	End
	{
		
	}
}

function backup-config
{
  <#
  .SYNOPSIS
  saves the config on a nexus switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	backup-config
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
	
	)
	
	begin
	{
	}
	
	process
	{
		
		$copyStatusisComplete = $false
		$obj = "" | Select-Object Hostname,CopyStatus
		
		$hostname = (get-switch).hostname
		$obj.hostname = $hostname
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")
		$sshStream.write("copy run start`n")
		$sshStream.write("end`n")
		start-sleep -Milliseconds 10000
		$output = (($sshStream.Read()).split("`n")).trim()
		
		foreach ($line in $output)
		{
			Write-Verbose "CMD:$line"
			if ($line -match '(Copy complete)')
			{
				$copyStatusisComplete = $true
			}
		}
		
		
		if ($copyStatusisComplete -eq $true)
		{
			$obj.copyStatus = 'Complete'
			
			Write-Output $obj
		}
		else
		{
			$obj.copyStatus = 'Failed'
			Write-Output $obj
		}
		
		
	}
	
	End
	{
		
	}
}

function enable-zoneset
{
  <#
  .SYNOPSIS
  Activates the changes in the zoneset
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch $switch -cred $credential
	enable-zoneset
	disconnect-switch -sshsession $sshSession
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		
	)
	
	begin
	{
	}
	
	process
	{
		
		$obj = "" | Select-Object Hostname, CopyStatus
		
		$activeZoneset = Get-ZoneSet
		$zoneset = $activeZoneset.zoneset
		$vsan = $activeZoneset.vsan
		
		$trash = $sshStream.Read()	# get rid of any pending output
		
		$sshStream.write("term length 0 ; config t`n")
		$sshStream.write("zoneset activate name $zoneset vsan $vsan`n")
		$sshStream.write("end`n")
		start-sleep -Milliseconds 2000
		$output = (($sshStream.Read()).split("`n")).trim()
		
		get-zonesetstatus -vsan $vsan
	}
	
	End
	{
		
	}
}

function connect-switch
{
  <#
  .SYNOPSIS
  Connects to the Cisco switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	$credential = get-credential
	$switch = 'switch_name_or_IP'
	
	connect-switch -switch [switch_ip] -cred (get-credential)
	
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$switch,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[pscredential]$credential
	)
	
	begin
	{
	}
	
	process
	{
		
		$global:sshsession = new-sshsession -computername $switch -credential $credential -AcceptKey
		$global:sshstream = $sshSession.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)	# Renci.SshNet.ShellStream CreateShellStream(string terminalName, uint32 columns, uint32 rows, uint32 width, uint32 height, int bufferSize)
		
		Write-Output $global:sshsession
	}
	
	End
	{
		
	}
}

function disconnect-switch
{
  <#
  .SYNOPSIS
  Disconnects from the Cisco switch
  .DESCRIPTION
  
  .EXAMPLE
	import-module Posh-SSH	
	# http://www.powershellmagazine.com/2014/07/03/posh-ssh-open-source-ssh-powershell-module/
	import-module csgp-cisco -force 
	
	disconnect-switch -session $sshSession

	
		
	
	
  .EXAMPLE
  
	
	
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[SSH.SshSession]$sshSession
	)
	
	begin
	{
	}
	
	process
	{
		remove-sshsession -sshsession $sshSession
	}
	
	End
	{
		
	}
}

<#
	.SYNOPSIS
		Returns fcalias and vsan information we will need to build the objects on the cisco
	
	.DESCRIPTION
	
	.PARAMETER computer
		the computer being added to the FC switch
	
	.PARAMETER fd
		The fibre channel failure domain (A or B)
	
	.PARAMETER pwwn
		The unique identifier for the FC port.  Cisco calls this a pwwn on the Nexus switch
	
	.PARAMETER san
		The friendly name of the san (DCSAN100, DCSAN101, ETC)
	
	.EXAMPLE
		PS C:\> initialize-zonedata -computer 'MyServer100' -fd A -san DCSAN100 -WWPN 20:00:00:25:b5:3a:00:00
	
	.NOTES
		Additional information about the function.
#>
function initialize-zonedata
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateSet("DCSAN100", "DCSAN101", "VISAN100", "VISAN102", "VISAN102", "LASAN100")]
		[string]$san,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateLength(1, 1)][ValidateSet("A", "B")]
		[string]$fd,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
		[string]$computer,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateLength(23, 23)]
		[string]$pwwn
		# 20:00:00:25:b5:3a:00:00
	)
	begin
	{
		
	}
	process
	{
		
		try
		{
			$isEven = Test-HostNameEven -computer $computer
			
		}
		catch
		{
			Write-Error "Unable to determine if host enumerator is even or odd"
		}
		
		try
		{
			
			if ($isEven -eq $true)
			{
				$hostParity = 'Even'
				if ($fd -eq "A") { $vsan = 10; $vhba = 'vhba1'; $arrayPort1 = 'spa0'; $arrayPort2 = 'spb1' }
				if ($fd -eq "B") { $vsan = 20; $vhba = 'vhba2'; $arrayPort1 = 'spa1'; $arrayPort2 = 'spb0' }
			}
			else
			{
				$hostParity = 'Odd'
				if ($fd -eq "A") { $vsan = 10; $vhba = 'vhba1'; $arrayPort1 = 'spa2'; $arrayPort2 = 'spb3' }
				if ($fd -eq "B") { $vsan = 20; $vhba = 'vhba2'; $arrayPort1 = 'spa3'; $arrayPort2 = 'spb2' }
			}
			
			$san = $san.ToLower()
			$fd = $fd.ToLower()
			$computer = $computer.ToLower()
			$pwwn = $pwwn.ToLower()
			
			$obj = "" | Select-Object HostFcAlias, ArrayFcAlias1, ArrayFcAlias2, Vsan, Pwwn
			$obj.HostFcAlias = "$($computer)_$($vhba)"
			$obj.ArrayFcAlias1 = "$($san)_$($arrayPort1)"
			$obj.ArrayFcAlias2 = "$($san)_$($arrayPort2)"
			$obj.Vsan = $vsan
			$obj.pwwn = $pwwn
			
			write-output $obj
		}
		catch
		{
			
		}
		
		
	}
	end
	{
	
	}
}

<#
	.SYNOPSIS
		 Test-HostNameEven fill figure out if the host name enumerator
		is even or odd

	.DESCRIPTION
		Used to spread out hosts between all 4 FC ports per EMC SP

	.PARAMETER  ParameterA
		The description of a the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of a the ParameterB parameter.

	.EXAMPLE
		PS C:\> Get-HostNameEven -computer dcappprd101
		$false

	.INPUTS
		System.String

	.OUTPUTS
		system.boolean

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
function Test-HostNameEven
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
		[string]$computer
	)
	begin
	{
	
	}
	process
	{
		try
		{
			# capture the enumerator at the end of the computer name
			# supports computer names ending in :
			# 123	- normal server
			# 123a	- new naming format for clusters
			# 123n1 - old naming format for clusters
			
			if ($computer -match '(\d\d\d)$')
			{
				$enumerator = $matches[1]
			}
			elseif ($computer -match '(\d\d\d)\w$')
			{
				$enumerator = $matches[1]
			}
			elseif ($computer -match '(\d\d\d)\w\d$')
			{
				$enumerator = $matches[1]
			}
			else
			{
				Write-Error ""	# cheezy way to get to catch {}
			}
			
			if ($enumerator % 2 -eq 0)
			{
				[system.Boolean]$result = $True
				Write-Output $result
				# Write-Output 'even'
			}
			else
			{
				[system.Boolean]$result = $False
				Write-Output $result
				# Write-Output 'odd'
			}
		}
		catch
		{
			Write-Error "Can't match enumerator in name $computer.  Is your format one of: host123, host123a, host123n1 ?"
		}
	}
	end
	{
		
	}
}
