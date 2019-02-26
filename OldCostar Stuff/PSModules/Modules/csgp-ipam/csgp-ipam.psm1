Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

#
# Infoblox WAPI documentation here: https://dcappprd416/wapidoc/
#



Function Set-TrustHTTPSendpoints
{
<#
	.SYNOPSIS
	Allows HTTPS endpoints using self-signed certs to be trusted, so that various REST API functions can run.

	.DESCRIPTION
	This is a basic "must run" function so that HTTPS endpoints using self-signed certs can be trusted, so that 


	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE

	.NOTES  
	File Name   : LN-Infoblox-Module.ps1
	Author      : Victor Chan - vchan@loopnet.com
	Requires    : PowerShell V2

	#>
	add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}


Function connect-Ipam
{
<#
	.SYNOPSIS
	This function simply asks for you credentials if it's not already set.  Will store globally so all the API calls can use that credential

	.DESCRIPTION
	

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	connect-ipam 

	.EXAMPLE
	connect-ipam -user myuser
	
	.NOTES  
	
	

#>
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[pscredential]$credential = (get-credential),
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$user,	
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	Set-TrustHTTPSendpoints
	remove-variable ipamCred -Scope global -ErrorAction 'SilentlyContinue'
	
	if ($credential)
	{
		$global:ipamCred = $credential
	}
	elseif ($user)
	{
		$global:ipamCred = Get-Credential -Credential $user
	}
	else
	{
		$global:ipamCred = Get-Credential -Credential "$env:username"
	}
	
	try
	{
		# test the API and password to ensure we have a valid connection
		$request = invoke-RestMethod -Uri "https://dcappprd416/wapi/v1.6/member" -credential $ipamcred
		$ref = $request._ref
		Write-verbose $ref
	}	
	catch
	{
		$res = [int]($_.Exception.Response).StatusCode
		Write-Output $res
		Throw "connection to Infoblox API at $infobloxserver did not work!  Response code sent from Infoblox is Exception is $res"
	}
	
	
}


Function disconnect-Ipam
{
<#
	.SYNOPSIS
	This function removes the $ipamCred global variable

	.DESCRIPTION
	

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	disconnect-ipam 

	.NOTES  
	
	

#>
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		
	)
	
	try
	{
		Remove-Variable -Scope global -Name ipamCred
	}
	catch
	{
		Write-Error "Unable to remove credential"	
	}
	
	
}


Function Find-IpamHost
{
<#
	.SYNOPSIS
	Finds detailed records as stored in infoblox

	.DESCRIPTION
	Finds detailed records as stored in infoblox; seperate multiple servers with commas.

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	Find-IpamHost -computer dcadmin8
	
	.EXAMPLE
	Find-IpamHost -computer dcadmin8,dcappprd408

	.NOTES  
	

#>
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False, HelpMessage = "Enter Host Names, seperated by commas")]
		[ValidateNotNullOrEmpty()]
		[array]$computer,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	BEGIN
	{

		
		if ($computer -match '^\d+.\d+.\d+.\d+$')
		{
			# matched an Ip address
			$useipv4addr = [boolean]$true
		}
		else
		{
			$useipv4addr = [boolean]$false
		}
		
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
	}
	
	PROCESS
	{
		foreach ($i in $computer)
		{
			$obj = @()
			$obj = "" | Select-Object Name, IPAddress, Description, Owner, Dns1, Dns2, Gateway, Netmask, VLANID, AdSite, City, State, Country, StatusCode, StatusDescription, Ref, Present
		
			try
			{
				# Use IP address or dns name
				
				if ($useipv4addr -eq $true)
				{
					$output = invoke-RestMethod -Uri "https://$infobloxserver/wapi/v1.6/record:host?ipv4addr=$i&_return_fields=name,ipv4addrs,extattrs" -Credential $ipamCred
				}
				else
				{
					$i = $i.tolower()
					$obj.Name = $i
					$output = invoke-RestMethod -Uri "https://$infobloxserver/wapi/v1.6/record:host?name:=$i&_return_fields=name,ipv4addrs,extattrs" -Credential $ipamCred
				}
				
				
				# if not match $output is empty, add some info to report and go to next loop invocation.
				if (! ($output))
				{
					$obj.present = [boolean]$false
					$report += $obj
					continue
				}
				else
				{
					# got a valid response from REST

					try { $obj.IPAddress = $output.ipv4addrs.ipv4addr }	catch {	$obj.IpAddress = 'n/a'}
					try { $obj.Description = $output.extattrs.'IP Address Description'.value }	catch { $obj.Description = 'n/a' }
					try { $obj.Owner = $output.extattrs.'IP Address Owner'.value } catch { $obj.owner = 'n/a' }
					try { $obj.vlanid = $output.extattrs.'vlan id'.value }	catch { $obj.vlanid = 'n/a' }
					try { $obj.Dns1 = $output.extattrs.'DNS1'.value }	catch { $obj.Dns1 = 'n/a' }
					try { $obj.Dns2 = $output.extattrs.'DNS2'.value }	catch { $obj.Dns2 = 'n/a' }
					try { $obj.Gateway = $output.extattrs.'Network Gateway IP'.value }	catch { $obj.Gateway = 'n/a' }
					try { $obj.Netmask = $output.extattrs.'Network Mask'.value }	catch { $obj.Netmask = 'n/a' }
					try { $obj.City = $output.extattrs.'Network City'.value }	catch { $obj.City = 'n/a' }
					try { $obj.State = $output.extattrs.'Network State'.value }	catch { $obj.State = 'n/a' }
					try { $obj.Country = $output.extattrs.'Network Country'.value }	catch { $obj.Country = 'n/a' }
					try { $obj.ref = $output._ref }	catch { $obj.ref = 'n/a' }
					
					
					$obj.present = [boolean]$true
					
					$report += $obj
				}
			}
			
			catch [System.Net.WebException]
			{
				# should only be here if the REST syntax is incorrect
				$obj.name = $i
				$obj.statuscode = [int]$_.Exception.Response.StatusCode
				$obj.StatusDescription = $_.Exception.Response.StatusDescription
				$report += $obj
			}
			
		}
		
		Write-Output $report
	}
	END
	{

	}
	
	
}

Function Get-IpamIpBlock
{
<#
	.SYNOPSIS
	Gets IP Block Information of server from IP Range

	.DESCRIPTION
	Gets Information of IP Block.  Note that, if $ipamCred variable not defined, this function will prompt for credentials to access Infoblox

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	Get-IpamIpBlock -IPRange 192.168.39.0/24

	.NOTES  
  
	

	#>
	
	[CmdletBinding(supportsshouldprocess = $True)]
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False, HelpMessage = "Enter CIDR network info, separated by commas")]
		[ValidateNotNullOrEmpty()]
		[array]$IPRange,
		
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	
	BEGIN
	{
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
	}
	
	Process
	{
		foreach ($range in $IPRange)
		{
			
			$obj = @()
			$obj = "" | Select-Object VlanName, VlanId, AdSite, Dns1, Dns2, Description, Gateway, Netmask, City, State, Country, Ref, Present
			
			
			
			try
			{
				$output = invoke-restmethod -Uri "https://$infobloxserver/wapi/v1.6/network?network=$range&_return_fields=network,extattrs" -credential $ipamCred
				# $output.extattrs.psobject.properties | foreach-object { Write-Output "$($_.Name)'s value is $($_.Value.value)" }
				
				# if not match $output is empty, add some info to report and go to next loop invocation.
				if (! ($output))
				{
					$obj.present = [boolean]$false
					$report += $obj
					continue
				}
				else
				{
					# got a valid response from REST
					try { $obj.vlanname = $output.extattrs.'vlan name'.value }	catch { $obj.vlanname = 'n/a' }
					try { $obj.vlanid = $output.extattrs.'vlan id'.value }	catch { $obj.vlanid = 'n/a' }
					try { $obj.AdSite = $output.extattrs.'AD Site'.value }	catch { $obj.AdSite = 'n/a' }
					try { $obj.Dns1 = $output.extattrs.'DNS1'.value }	catch { $obj.Dns1 = 'n/a' }
					try { $obj.Dns2 = $output.extattrs.'DNS2'.value }	catch { $obj.Dns2 = 'n/a' }
					try { $obj.Description = $output.extattrs.'Network Description'.value }	catch { $obj.Description = 'n/a' }
					try { $obj.Gateway = $output.extattrs.'Network Gateway IP'.value }	catch { $obj.Gateway = 'n/a' }
					try { $obj.Netmask = $output.extattrs.'Network Mask'.value }	catch { $obj.Netmask = 'n/a' }
					try { $obj.City = $output.extattrs.'Network City'.value }	catch { $obj.City = 'n/a' }
					try { $obj.State = $output.extattrs.'Network State'.value }	catch { $obj.State = 'n/a' }
					try { $obj.Country = $output.extattrs.'Network Country'.value }	catch { $obj.Country = 'n/a' }
					try { $obj.ref = $output._ref } catch { $obj.ref = 'n/a' }
					
					$obj.present = [boolean]$true
					
					$report += $obj
				}
				
			}
			catch
			{
				$res = [int]($_.Exception.Response).StatusCode
				Write-Output $res
				Throw "connection to Infoblox API at $infobloxserver did not work!  Response code sent from Infoblox is Exception is $res"
			}
		}
		
		Write-Output $report
	}
	
	End
	{
		
	}
	
}

Function Get-IpamNetworkByEa
{
<#
	.SYNOPSIS
	Gets IP Block Information by searching extensible attribute information

	.DESCRIPTION
	Note that, if $ipamCred variable not defined, this function will prompt for credentials to access Infoblox

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	Get-IpamNetworkByEa -Name 'Network State' -Value 'California'

	.EXAMPLE
	Get-IpamNetworkByEa -Name 'Network Purpose' -Value 'PRINTER'

	
	.NOTES  
    
	

	#>
	
	[CmdletBinding(supportsshouldprocess = $True)]
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False, HelpMessage = "Enter Host Extensible Attribute Name")]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False, HelpMessage = "Enter Host Extensible Attribute value")]
		[ValidateNotNullOrEmpty()]
		$Value,
		
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	
	BEGIN
	{
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
		
		if ($Name -eq 'VLAN ID')
		{
			Write-Error "Have not figured out how to search on an INTEGER ($VALUE) yet..."
		}
	}
	
	Process
	{
		#		foreach ($range in $IPRange)
		#		{
		#
		$obj = @()
		$obj = "" | Select-Object VlanName, VlanId, AdSite, Dns1, Dns2, Description, Gateway, Netmask, City, State, Country, Ref, Present
		
		# replace any spaces with a + to support CGI syntax
		$eaCgiName = $Name -replace "\s+", "+"
		
		try
		{
			
			$output = invoke-restmethod -credential $ipamCred -Uri "https://$infobloxserver/wapi/v1.6/network?*$eaCgiName`:=$Value&_return_fields=network,extattrs"  # Note the backtick `:=
			# &_return_fields=network,extattrs" -credential $ipamCred
			# $output.extattrs.psobject.properties | foreach-object { Write-Output "$($_.Name)'s value is $($_.Value.value)" }
			
			# if not match $output is empty, add some info to report and go to next loop invocation.
			if (! ($output))
			{
				$obj.present = [boolean]$false
				$report += $obj
				continue
			}
			else
			{
				foreach ($item in $output)
				{
					
					# Not all EA are filled out in infoblox so we have to be defensive when returning info
					# got a valid response from REST
					
					$obj = @()
					$obj = "" | Select-Object VlanName, VlanId, AdSite, Dns1, Dns2, Description, Gateway, Netmask, City, State, Country, Ref, Present
					
					
					write-verbose "($item)"
					
					try { $obj.vlanname = $item.extattrs.'vlan name'.value }
					catch { $obj.vlanname = 'n/a' }
					try { $obj.vlanid = $item.extattrs.'vlan id'.value }
					catch { $obj.vlanid = 'n/a' }
					try { $obj.AdSite = $item.extattrs.'AD Site'.value }
					catch { $obj.AdSite = 'n/a' }
					try { $obj.Dns1 = $item.extattrs.'DNS1'.value }
					catch { $obj.Dns1 = 'n/a' }
					try { $obj.Dns2 = $item.extattrs.'DNS2'.value }
					catch { $obj.Dns2 = 'n/a' }
					try { $obj.Description = $item.extattrs.'Network Description'.value }
					catch { $obj.Description = 'n/a' }
					try { $obj.Gateway = $item.extattrs.'Network Gateway IP'.value }
					catch { $obj.Gateway = 'n/a' }
					try { $obj.Netmask = $item.extattrs.'Network Mask'.value }
					catch { $obj.Netmask = 'n/a' }
					try { $obj.City = $item.extattrs.'Network City'.value }
					catch { $obj.City = 'n/a' }
					try { $obj.State = $item.extattrs.'Network State'.value }
					catch { $obj.State = 'n/a' }
					try { $obj.Country = $item.extattrs.'Network Country'.value }
					catch { $obj.Country = 'n/a' }
					try { $obj.ref = $item._ref }
					catch { $obj.ref = 'n/a' }
					
					$obj.present = [boolean]$true
					
					$report += $obj
				}
			}
			
		}
		catch
		{
			$res = [int]($_.Exception.Response).StatusCode
			Write-Output $res
			Throw "connection to Infoblox API at $infobloxserver did not work!  Response code sent from Infoblox is Exception is $res"
		}
		# }
		
		Write-Output $report
	}
	
	End
	{
		
	}
	
}

Function New-IpamHostNextAvailable
{
<#
	.SYNOPSIS
	Given an IP block (CIDR) will get the next available IP address and register a host

	.DESCRIPTION
	Note that, if $ipamCred variable not defined, this function will prompt for credentials to access Infoblox

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	New-IpamHostNextAvailable -computer deleteme2 -ipDescription "testing ipam automation" -ipOwner "systems" -network 10.227.20.0/22

	.NOTES  
    
	

	#>
	
	[CmdletBinding(supportsshouldprocess = $True)]
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$computer,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$network,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ipDescription,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ipOwner,
			
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	
	BEGIN
	{
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
		
		
	}
	
	Process
	{
		
		$hostInfo = Find-IpamHost -computer $computer
		
		if ($hostInfo.Present -eq $True)
		{
			Write-Error "Can't create new record, host already exists: $computer"
		}
		
		
		$computer = $computer.ToLower()
		$json = @"
			{
				"ipv4addrs":[
				{
					"configure_for_dhcp":false,
					"ipv4addr":"func:nextavailableip:$network"
				}
				],
				"name":"$computer",
				"configure_for_dns":false,
				"extattrs":{
					"IP Address Description":{
						"value":"$ipDescription"
					},
					"IP Address Owner":{
						"value":"$ipOwner"
					}
				}
			}
"@
		
		# Register the new host record
		$result = Invoke-RestMethod -URI "https://$InfoBloxServer/wapi/v1.6/record:host" -Credential $ipamCred -Body $json -method post -contentType "application/json"
		
		
		$hostInfo = Find-IpamHost -computer $computer
		Write-output $hostInfo
	}
	
	End
	{
		
	}
	
}

Function New-IpamHost
{
<#
	.SYNOPSIS
	Given an IP block (CIDR) will register a host using an IP you specify

	.DESCRIPTION
	Note that, if $ipamCred variable not defined, this function will prompt for credentials to access Infoblox

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	New-IpamHost -computer deleteme1 -ipAddress 10.227.20.40 -ipDescription "testing ipam automation" -ipOwner "systems" -network 10.227.20.0/22

	.NOTES  
    
	

	#>
	
	[CmdletBinding(supportsshouldprocess = $True)]
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$computer,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$network,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ipAddress,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ipDescription,
		
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ipOwner,
		
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	
	BEGIN
	{
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
		
		
	}
	
	Process
	{
		
		$hostInfo = Find-IpamHost -computer $computer
		
		if ($hostInfo.Present -eq $True)
		{
			Write-Error "Can't create new record, host already exists: $computer"
		}
		
		$computer = $computer.ToLower()
		$json = @"
			{
				"ipv4addrs":[
				{
					"configure_for_dhcp":false,
					"ipv4addr":"$ipAddress"
				}
				],
				"name":"$computer",
				"configure_for_dns":false,
				"extattrs":{
					"IP Address Description":{
						"value":"$ipDescription"
					},
					"IP Address Owner":{
						"value":"$ipOwner"
					}
				}
			}
"@
		
		# Register the new host record
		$result = Invoke-RestMethod -URI "https://$InfoBloxServer/wapi/v1.6/record:host" -Credential $ipamCred -Body $json -method post -contentType "application/json"
		
		
		$hostInfo = Find-IpamHost -computer $computer
		Write-output $hostInfo
	}
	
	End
	{
		
	}
	
}

Function remove-IpamHost
{
<#
	.SYNOPSIS
	

	.DESCRIPTION
	

	LATEST CHANGES:
	v1.0 - Initial release.

	.EXAMPLE
	remove-IpamHost -computer 10.100.100.254
	
	.EXAMPLE
	remove-IpamHost -computer deleteme1

	.EXAMPLE
	remove-IpamHost -computer deleteme1,deleteme2
	
	.NOTES  
    
	

	#>
	
	[CmdletBinding(supportsshouldprocess = $True)]
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[array]$computer,
		
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$infobloxserver = 'dcappprd416'
	)
	
	
	
	BEGIN
	{
		Set-TrustHTTPSendpoints # Trust self signed certs
		$report = @()
		
		
	}
	
	Process
	{
		
		foreach ($i in $computer)
		{
			$hostInfo = Find-IpamHost -computer $i
			if ($hostInfo.Present -eq $false)
			{
				continue
			}
			
			# Delete the record
			$ref = $hostInfo.ref
			Write-Verbose "Will delete $ref"
			$result = Invoke-RestMethod -URI "https://$InfoBloxServer/wapi/v1.6/$ref" -Credential $ipamCred -method delete
			
			write-output $result
		}
		
		
	}
	
	End
	{
		
	}
	
}



# Additional Infoblox rest examples: https://community.infoblox.com/t5/API-Integration/The-definitive-list-of-REST-examples/td-p/1214