﻿
				
#REQUIRES -Version 2.0


#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function Get-NetworkAdapterForDnsUpdate
{
  <#
  .SYNOPSIS
  Find a network adapter that has a default gateway
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$result = Test-WMI -computer $computer
		
		
		if ($result.WmiTestStatus -eq 'pass')
		{
			$wmiNetworkAdapterConfiguration = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Computer $computer
			foreach ($networkAdapter in $wmiNetworkAdapterConfiguration)
			{
				try
				{
					if ($networkAdapter.DefaultIPGateway[0])
					{
						Write-Output $networkAdapter
					}
				}
				catch
				{
					
				}
			}
		}
		else
		{
			# wmiteststatus was not 'pass' so get out of this loop
			return	
		}
		
	}
	
	End
	{
		
	}
}

function Get-NetworkAdapterForDnsUpdateLoopNet
{
  <#
  .SYNOPSIS
  Find a LoopNet network adapter that has any DNS servers defined.  
  .DESCRIPTION
  We have to use this function because their servers have a nic with a default GW but it has no DNS ser
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$result = Test-WMI -computer $computer
		
		
		if ($result.WmiTestStatus -eq 'pass')
		{
			$wmiNetworkAdapterConfiguration = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Computer $computer
			foreach ($networkAdapter in $wmiNetworkAdapterConfiguration)
			{
				try
				{
					if ($networkAdapter.DNSServerSearchOrder)
					{
						Write-Output $networkAdapter
					}
				}
				catch
				{
					
				}
			}
		}
		else
		{
			# wmiteststatus was not 'pass' so get out of this loop
			return
		}
		
	}
	
	End
	{
		
	}
}

function Set-DNSServersOnNic
{
  <#
  .SYNOPSIS
  This function will set the DNS servers on the server nic
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Use the built-in hash table to figure out what DNS servers to use (preferred)
  Set-DNSServersOnNic -computer [computername] -site Reston -zone dmz
  .EXAMPLE
  Manual override of DNS servers
  Set-DNSServersOnNic -computer [computername] -dnsList @("10.228.80.20","10.228.80.21")
  
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$computer,
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, HelpMessage = "Specify Reston, LAX, Vienna, or Boston")]
		[ValidateSet('Reston', 'LAX', 'Vienna', 'Boston','us-east-1','us-east-1-vpc230','us-west-1','us-west-2')]
		[string]$site,
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, HelpMessage = "Specify int or dmz")]
		[ValidateSet('int','dmz')]
		[string]$zone,
		[parameter(Mandatory = $False, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[array]$dnsList
	
	)
	
	begin
	{
		
		if (((! $dnsList) -and (! $site)) -or ((! $dnsList) -and (! $zone)))
		{
			Write-Error "You must supply `$dnsList or `$site & `$zone"	
		}
		
		$dnsServers = @{
			'Reston' = @{
				'int' = @("172.16.235.200", "172.17.132.200", "172.16.255.200")
				'dmz' = @("172.16.235.201", "172.17.132.201", "172.16.255.201")
			}
			'LAX' = @{
				'int' = @("172.16.254.200", "172.17.155.200", "172.16.235.200")
				'dmz' = @("172.16.254.201", "172.17.155.201", "172.16.235.201")
			}
			'Vienna' = @{
				'int' = @("172.16.255.200", "172.16.235.200", "172.17.132.200")
				'dmz' = @("172.16.255.201", "172.16.235.201", "172.17.132.201")
			}
			'Boston' = @{
				'int' = @("10.103.2.28", "10.103.2.27", "172.16.235.200")
				'dmz' = @("10.103.2.28", "10.103.2.27", "172.16.235.200")
			}
			'us-east-1' = @{
				'int' = @("10.227.20.20", "10.227.20.21")
				'dmz' = @("10.227.20.20", "10.227.20.21")
			}
			'us-east-1-vpc230' = @{
				'int' = @("10.230.80.20", "10.230.80.21", "10.230.20.20", "10.230.20.21", "172.16.235.202", "172.16.254.202")
				'dmz' = @("10.230.80.20", "10.230.80.21", "10.230.20.20", "10.230.20.21", "172.16.235.202", "172.16.254.202")
			}
			'us-west-1' = @{
				'int' = @("10.228.20.20", "10.228.20.21")
				'dmz' = @("10.228.20.20", "10.228.20.21")
			}
			'us-west-2' = @{
				'int' = @("10.229.20.20", "10.229.20.21")
				'dmz' = @("10.229.20.20", "10.229.20.21")
			}
			
		}
		
	}
	
	process
	{
		$wmiNic = Get-NetworkAdapterForDnsUpdate -computer $computer
		
		try
		{
			$obj = @()
			if ($dnsList)
			{
				$result = $wmiNic.setDNSServerSearchOrder($dnsList)
			}
			else
			{
				$result = $wmiNic.setDNSServerSearchOrder($dnsServers.Item($site).$zone)
			}
			$newWmiNic = Get-NetworkAdapterForDnsUpdate -computer $computer
			$obj = "" | Select-Object Computername, ReturnValue, DNSServerSearchOrder
			$newDnsSearchOrder = ""
			foreach ($dnsServer in $newWmiNic.DNSServerSearchOrder)
			{
				$newDnsSearchOrder += $dnsServer+","
			}
			$obj.Computername = $computer
			
			if ($result.returnvalue -eq 0)
			{
				$obj.ReturnValue = "pass"
			}
			else
			{
				$obj.ReturnValue = "fail"
			}
			# remove traling comma from dns search list
			$newDnsSearchOrder = $newDnsSearchOrder -replace ",$", ""
			$obj.DNSServerSearchOrder = $newDnsSearchOrder
			Write-Output $obj
		}
		catch
		{
			$obj = "" | Select-Object Computername, ReturnValue, DNSServerSearchOrder
			$obj.Computername = $computer
			$obj.ReturnValue = 'fail'
			Write-Output $obj
		}
		
	}
	
	End
	{
		
	}
}

function Get-DNSServersOnNic
{
  <#
  .SYNOPSIS
  This function will get the DNS servers on the server nic
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
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$computer
		
	)
	
	begin
	{
		
		
	}
	
	process
	{
		try
		{
			$newWmiNic = Get-NetworkAdapterForDnsUpdate -computer $computer
			$obj = "" | Select-Object Computername, WMIComputername, DNSServerSearchOrder
			$newDnsSearchOrder = ""
			foreach ($dnsServer in $newWmiNic.DNSServerSearchOrder)
			{
				$newDnsSearchOrder += $dnsServer + ","
			}
			$obj.Computername = $computer
			$newDnsSearchOrder = $newDnsSearchOrder -replace ",$", ""
			$obj.DNSServerSearchOrder = $newDnsSearchOrder
			Write-Output $obj
		}
		catch
		{
			$obj = "" | Select-Object Computername, DNSServerSearchOrder
			$obj.Computername = $computer
			$obj.DNSServerSearchOrder = 'fail'
			Write-Output $obj
		}
		
	}
	
	End
	{
		
	}
}

function Get-DNSServersOnNicLoopNet
{
  <#
  .SYNOPSIS
  This function will get the DNS servers on the server nic
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
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$computer
		
	)
	
	begin
	{
		
		
	}
	
	process
	{
		try
		{
			$newWmiNic = Get-NetworkAdapterForDnsUpdateLoopNet -computer $computer
			foreach ($wmiNic in $newWmiNic)
			{
				$obj = "" | Select-Object Computername, WMIComputername, DNSServerSearchOrder
				$newDnsSearchOrder = ""
				foreach ($dnsServer in $wmiNic.DNSServerSearchOrder)
				{
					$newDnsSearchOrder += $dnsServer + ","
				}
				$obj.Computername = $computer
				$obj.WmiComputerName = $wmiNic.__SERVER
				$newDnsSearchOrder = $newDnsSearchOrder -replace ",$", ""
				$obj.DNSServerSearchOrder = $newDnsSearchOrder
				Write-Output $obj
			}
		}
		catch
		{
			$obj = "" | Select-Object Computername, DNSServerSearchOrder
			$obj.Computername = $computer
			$obj.DNSServerSearchOrder = 'fail'
			Write-Output $obj
		}
		
	}
	
	End
	{
		
	}
}