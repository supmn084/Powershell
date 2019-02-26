#REQUIRES -Version 2.0

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

function get-spListAllFields	{
	# Connect to the EsxBuilds list and dump out all info for each row
 	[CmdletBinding()]
	param(
			[parameter(Mandatory=$true)]
			    [string]$uri,
		    [parameter(Mandatory=$true)]
			    [string]$sharepointList,
			[parameter(Mandatory=$true)]
			    [int]$id
		)

	# create the web service
	write-verbose "LOG: Accessing list $sharepointList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri

	# Get rows
	$listRows = get-spListItems -listname $sharepointList -service $service | ? { $_.ows_ID -eq $id }
	write-verbose "LOG: got list row, found ID $($listRows.ows_id), Title: $($listRows.ows_title)"
	
	Write-Output $listRows
}	

function Initialize-spData {
	<#
		.SYNOPSIS
			This function takes in the raw sharepoint row and selects important
			fields relevant to the build.  Adds to a Powershell Object that we'll use quite frequently, this object will have
			all the characteristics of hte ESX server

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		$spAllFieldsObj
		)

	$listRows = $spAllFieldsObj
	
	# Make sure to trim() every property or you will allow a user to create objects with spaces at the end or beginning (bad)
	
	$r = @()  # r is short for "request"
	$r = "" | Select-Object ID,Hostname,vCenterDataCenterName,DataCenterLocation,ITEnvironment,ITSubEnvironment,vmkernelManagement0,vmkernelVmotion0,vmkernelFaultTol0,vmkernelIpstorage0,vmkernelIpstorage1,ApplicationName,ServerRole,CotsWithSql,SubsidiaryName,ITProjectDescription,OperatingSystem,LicenseKey,TestLabHost,HostStorageType,UsingHpVirtualConnect,HostClusterName,UsesChapForIscsi,SupportsVdsSwitch
	$r.ID = $listRows.ows_id
	$r.Hostname = $listRows.ows_title.trim().tolower()
	if ( ($listRows.ows_ITEnvironment -eq 'DEV') -or ($listRows.ows_ITEnvironment -eq 'TST') ) {
		$r.ITEnvironment = 'DEVTST'
	} else {
		$r.ITEnvironment = $listRows.ows_ITEnvironment
	}
	$r.ITSubEnvironment = $listRows.ows_ITSubEnvironment
	$r.vCenterDataCenterName = $listRows.ows_vCenterDataCenterName
	$r.DataCenterLocation = $listRows.ows_DataCenterLocation
	$r.ApplicationName = $listRows.ows_ApplicationName.trim()
	$r.ServerRole = 'App'	# This is set statically here so I don't have to modify the pre-build modules I'm reusing
	$r.CotswithSql = '0'	# This is set statically here so I don't have to modify the pre-build modules I'm reusing
	$r.ITProjectDescription = 'ESXi Server' # This is set statically here so I don't have to modify the pre-build modules I'm reusing
	$r.OperatingSystem = 'VMware ESXi' # This is set statically here so I don't have to modify the pre-build modules I'm reusing
	$r.SubsidiaryName = $listRows.ows_SubsidiaryName
	$r.vmkernelManagement0 = $listRows.ows_vmkernelManagement0
	$r.vmkernelVmotion0 = try { $listRows.ows_vmkernelVmotion0 } catch { 'Empty' }
	$r.vmkernelFaultTol0 = try { $listRows.ows_vmkernelFaultTol0 } catch { 'Empty' }
	$r.vmkernelIpstorage0 = try { $listRows.ows_vmkernelIpstorage0 } catch { 'Empty' }
	$r.vmkernelIpstorage1 = try { $listRows.ows_vmkernelIpstorage1 } catch { 'Empty' }
	$r.LicenseKey = $listRows.ows_Licensekey.trim()
	$r.HostStorageType = $listRows.ows_HostStorageType
	$r.TestLabHost = $listRows.ows_TestLabHost
	$r.UsingHpVirtualConnect = $listRows.ows_UsingHpVirtualConnect
	$r.HostClusterName = $listRows.ows_HostClusterName.trim() # string
	$r.UsesChapForIscsi = $listRows.ows_UsesChapForIscsi
	$r.SupportsVdsSwitch = $listRows.ows_SupportsVdsSwitch
	

	Write-Output $r
}

function initialize-vCenter {
	# Get a vCenter connection
	[CmdletBinding()]
	param(
			[parameter(Mandatory=$true)]
			    [string]$viServer,
			[parameter(Mandatory=$false)]
			    [System.Management.Automation.PSCredential]$cred,
			[parameter(Mandatory=$false)]
			    [string]$user,
			[parameter(Mandatory=$false)]
			    [string]$password
	)
	

	try {
		if ($defaultviserver.isconnected) {write-verbose "LOG: Already connected to $($defaultviserver.name)" }
		$vi = get-viserver $viserver
	} catch {
		# connect to vCenter and don't display cert warning
		write-verbose "LOG: Connecting to $viserver"
		if ($cred)
		{
			$vi = Connect-VIServer $viserver -credential $cred -WarningAction SilentlyContinue -ErrorAction Stop
		}
		elseif ($user -or $password )
		{
			$vi = Connect-VIServer $viserver -User $user -Password $password -WarningAction SilentlyContinue -ErrorAction Stop
		}
		else 
		{
			$vi = Connect-VIServer $viserver -WarningAction SilentlyContinue -ErrorAction Stop		
		}
	}
	
	Write-Output $vi
}

function new-esxEntPlusVirtualStandardSwitch {
	<#
		.SYNOPSIS
			This function creates a virtual standard switch for 'virtual machine network' with all the fixins. 
			It will only be used for Enterprise+ hosts where the cluster has not been migrated to a vDs.  The
			idea is that vmnic3 will be hooked into this vSwitch and then we'll move vmnic4 to the vDs and then 
			perform the migration to vDs.  Then add vmnic3 to the vDs.
			
			If all the Enterprise+ hosts in the cluster are on a vDS you may stop using this function.

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[hashtable]$esxvssDef,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$esxEnvDefKey,
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		[parameter(Mandatory=$false,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$vSwitchName
		)

	try
	{
		$result = $vmhost | Get-VirtualSwitch -Name $vSwitchName
		Write-output $result
	}
	catch
	{
		Write-Verbose "Creating vss $vSwitchName.."
		$vSwitch = New-VirtualSwitch -Name $vSwitchName -VMHost $vmHost -numports 1016 -Confirm:$false -ErrorAction Stop
		foreach ($vss in ($esxvssDef.item($esxEnvDefKey).getenumerator()) )	{
			$vssPgName = $vss.Name
			$vssVlanId = $vss.value
			$result = New-VirtualPortGroup -Name $vssPgName -VLanId $vssVlanId -VirtualSwitch $vSwitchName -Confirm:$false -ErrorAction Stop
		}
		
		# Set switch security
		$vswitch | set-csgpvSwitchSecurity
		Write-Output $result
	}
	
}

function add-vmHostToVcenter {
	<#
		.SYNOPSIS
			This function will test that the specifid cluster exists and will add the host to vCenter

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$Hostname,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
			$spBuildData,
			[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSCredential]$cred
		)
	
	# Add host to vCenter and an existing cluster.  Fail if cluster does not exist
	try 
	{
		$hostCluster = get-cluster $($spBuildData.HostClusterName)
	}
	catch
	{
		Write-Error "VM Cluster `'$($spBuildData.HostClusterName)`' does not exist.  Manually create in vCenter and try again"
	}
	
	
	# Add host to vCenter
	try 
	{
		if ( ($vmhost = Get-VMHost $Hostname) ) {
			# If host already exists just send back the object
			write-output $vmhost
			return
		}
	}
	catch
	{
		# Try() failed so we will add the host
		$vmhost = add-vmhost -name $hostname -Location $hostCluster -Credential $cred -force:$true -RunAsync:$false
		Write-Output $vmHost
	}

}

function get-csgpCredential {
	<#
		.SYNOPSIS
			This function uses PSHostUserInterface.PromptForCredential to prompt for credentials

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$caption,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$message,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$username,
		[parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[string]$domain=$null
	
		)

	$cred = $Host.UI.PromptForCredential($caption,$message,$username,$domain)
	# Powershell 2.0 PromptForCredential() has a bug where if there is no domain specified a "\" is inserted before the username
	#	this will clean that up.
	$credClean = New-Object -TypeName 'System.Management.Automation.PSCredential' -ArgumentList $cred.Username.Replace("\",""),$cred.Password
	Write-Output $credClean
	
}

function update-rootPassword {
	<#
		.SYNOPSIS
			This function will update the initial root password to the permanent password

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$Hostip,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$initialRootPassword,
		[parameter(Mandatory=$true)]
		[System.Management.Automation.PSCredential]$cred
			
		)

	# Reconnect to the host with the new IP provided from SharePoint
	try
	{
		write-host "Trying to connect to $Hostip using the default password from the Kickstart build ($initialRootPassword)"
		$vi = initialize-vCenter -viServer $Hostip -user root -password $initialRootPassword
	}
	catch
	{
		# If we were unable to connect to the host using the password from the 
		#	Kickstart build maybe that means we have already run this script
		#   one or more times and we should use the permanent password
		#   instead
		if (! (test-path variable:vi) ) {
			try
			{
				write-host "Default build password not accepted, trying to connect to $Hostip using the permanent password"
				$vi = initialize-vCenter -viServer $Hostip -user root -password $cred.GetNetworkCredential().password
			}
			catch
			{
				Write-Error "The root password supplied did not match either the initial or permanent password"
			}
		}
	}
	
	try
	{
		$vmhostDirect = get-vmhost -Server $vi.Name
		Write-Host "Connected locally to host $($vmhostdirect.name)" -ForegroundColor Green
	}
	catch
	{
		Write-Error "Unable to connect to locally to host $($vmhostdirect.name) $error[0]"
	}

	# Until now, we were using the password from the ks.cfg that we embed in the ISO
	#	Change to our standard password
	$rootAccount = Get-VMHostAccount -User -Id root
	$setRootPasswordResult = Set-VMHostAccount -UserAccount $rootAccount -Password $cred.GetNetworkCredential().password
	disconnect-viserver * -Confirm:$false
	Remove-Variable vi
	Remove-variable vmhostDirect

}

function update-DhcpToStaticIp {
	<#
		.SYNOPSIS
			This function will convert the DHCP address to a static IP address

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$hostIp,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$staticIp,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$netmask,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$password,
		[parameter(Mandatory=$true)]
		[System.Management.Automation.PSCredential]$cred
		)

	# Change the DHCP address to static IP
	#$vi = initialize-vCenter -viServer $dhcpIp -user root -password $password
	# Reconnect to the host with the new IP provided from SharePoint
	try
	{
		write-host "Trying to connect to $Hostip using the default password from the Kickstart build"
		$vi = initialize-vCenter -viServer $Hostip -user root -password $initialRootPassword
	}
	catch
	{
		# If we were unable to connect to the host using the password from the 
		#	Kickstart build maybe that means we have already run this script
		#   one or more times and we should use the permanent password
		#   instead
		if (! (test-path variable:vi) ) {
			try
			{
				write-host "Default build password not accepted, trying to connect to $Hostip using the permanent password you provided"
				$vi = initialize-vCenter -viServer $Hostip -user root -password $cred.GetNetworkCredential().password
			}
			catch
			{
				Write-Error "The root password supplied did not match either the initial or permanent password"
			}
		}
	}
	$vmhostDirect = get-vmhost -Server $vi.Name

	# This esxcli call is async so it will return without failing after the IP has changed in-flight
	$esxcliDirect = $vmhostDirect | get-esxcli
	$dhcpIpSetResult = $esxcliDirect.network.ip.interface.ipv4.set('vmk0',$staticIp,$netmask,'false','static')
	disconnect-viserver * -Confirm:$false	# disconnect because we just changed the IP address
	Remove-Variable vi
	Remove-variable vmhostDirect
	Remove-variable esxcliDirect

}

function update-vmHostHostname {
	<#
		.SYNOPSIS
			This function will change the hostname of the host

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$hostIp,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$hostname,
		[parameter(Mandatory=$true)]
		[System.Management.Automation.PSCredential]$cred
		)

	# Connect to the host with the new IP provided from SharePoint
	$vi = initialize-vCenter -viServer $hostIp -user root -password $cred.GetNetworkCredential().password
	$vmhostDirect = get-vmhost -Server $vi.Name
	
	# Set new hostname.  Gen8 blades will show 'localhost' in the OA if we don't do this right away.  Get's confusing.
	$setHostnameResult = $vmhostDirect | Get-VMHostNetwork | Set-VMHostNetwork -HostName $hostname -Confirm:$false
	disconnect-viserver * -Confirm:$false
	Remove-Variable vi
	Remove-variable vmhostDirect

}


function set-StandAloneHostMaintenanceMode {
	<#
		.SYNOPSIS
			This function will connect to a local host and put into maintenance mode

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$hostname,
		[parameter(Mandatory=$true)]
		[System.Management.Automation.PSCredential]$cred
			
		)

	# Reconnect to the host with the new IP provided from SharePoint
	$vi = initialize-vCenter -viServer $hostname -cred $cred
	$vmhostDirect = get-vmhost -Server $vi.Name

	$esxcliDirect = $vmhostDirect | get-esxcli
	$maintModeStatus = $esxcliDirect.system.maintenanceMode.get()
	if ($maintModeStatus -eq 'Disabled')	{
		# if not already in maint mode, set to maint mode
		$esxcliDirect.system.maintenanceMode.set($true,'')
	}
	# disconnect because we just changed the IP address
	disconnect-viserver * -Confirm:$false
	Remove-Variable vi
	Remove-variable vmhostDirect
	Remove-variable esxcliDirect

}

<#
.SYNOPSIS
Adds the esxi server to the Active Directory domain
Version 1.00

.DESCRIPTION

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE


#>
function new-csgpEsxAdComputerAccount {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$CHANGEME
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		# This allows you to use -WhatIf
		If ($PSCmdlet.ShouldProcess("Adding +1 to: $thatVar")) { 
			Write-Output $($thatVar + 1)
		}
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Adds a disconnected virtual switch that will support vm cloning if needed

.DESCRIPTION

#>
function add-csgpTemplatevSwitch {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
)

	BEGIN
	{
		$vSwitchName = 'template-internal-only'
		$portGroupName = 'template-pg'
	}
	PROCESS	
	{
		
	try
	{
		$result = $vmhost | Get-VirtualSwitch -Name $vSwitchName
		Write-Output $result
	}
	catch
	{
		Write-Verbose "Creating template-internal-only vSwitch.."
		$vSwitch = New-VirtualSwitch -Name $vSwitchName -VMHost $vmHost -Confirm:$false -ErrorAction Stop
		$result = New-VirtualPortGroup -Name 'template-pg' -VirtualSwitch $vSwitch -Confirm:$false -ErrorAction Stop
		write-output $result
	}

	}
	END
	{

	}	

}

<#
.SYNOPSIS
Ensures that vmnic1 is active in vSwitch0. By default it is standby
Version 1.00

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE


#>
function set-csgpVmnic1Active {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.VirtualSwitchImpl]$vSwitch
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$nicPolicy = $vSwitch |  Get-NicTeamingPolicy
		if ($nicPolicy | ? {$_.StandbyNic -ne $null})	{
			# ESXi setup configures vmnic1 as standby, change it to Active
			$result = $nicpolicy | % {set-nicteamingpolicy -makenicactive $($_.StandbyNic) -virtualswitchpolicy $nicpolicy }
			write-output $result
		} else {
			# no changes
			Write-Output $nicPolicy
		}
	}
	END
	{

	}	
}

<#
.SYNOPSIS
Figures out if vMotion or Fault Tolerance is enabled and will display info
Version 1.00

.DESCRIPTION

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE

#>
function get-vmkernalVirtualNicInfo {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[ValidateNotNullOrEmpty()]
	[string]$vmkProperty
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$result = $vmhost | get-VMHostNetworkAdapter | ? {($_.DeviceName -like "vmk*") -and ($_.$vmkProperty -eq $true) }
		Write-output $result
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Adds vmks to the vmhbaxx iSCSI hba
Version 1.00

.DESCRIPTION

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE


#>
function add-VmkernelToIscsiHba {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Host.Networking.Nic.HostVMKernelVirtualNicImpl]$vmk,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[ValidateNotNullOrEmpty()]
	[string]$iscsiHbaName
)

	BEGIN
	{

	}
	PROCESS	
	{
	
		$esxcli = $vmHost | Get-EsxCli
		$vmkIp = $vmk.ip
		$vmkName = $vmk.name
		
		Write-Host "vmk ip to add to $iscsiHbaName : $vmkIp"
		
		if ( ($esxcli.iscsi.networkportal.list() | ? {$_.ipv4 -eq $vmkIp }) ) {
			Write-Host "$vmkName already found/bound on $iscsiHbaName"
			return
		}
		Write-Verbose "Adding $vmkName to $iscsiHbaName"
		try
		{
			$esxcli.iscsi.networkportal.add($iscsiHbaName, $false, $vmkName)
		}
		catch
		{
			write-host "$($_.Exception)"
			Write-Error "Unable to bind vmkNic $vmkName to $iscsiHbaName.  If you get the error 'Unable to bind iscsi port' that may mean that your dvUplink for iSCSI is not bound to a specific dvUpink.  Or, maybe you have the host attached to the dvSwitch but don't have the uplinks attached. $($error[0])"
		}
	}
	END
	{

	}	
}


function get-VmHostIscsiBinding {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[ValidateNotNullOrEmpty()]
	[string]$vmkName,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
	[ValidateNotNullOrEmpty()]
	[string]$iscsiHbaName
)

	BEGIN
	{

	}
	PROCESS	
	{
		$esxcli = $vmHost | Get-EsxCli
		$iscsiHbaInfo = $esxcli.iscsi.networkportal.list($iscsiHbaName)
		if (test-path variable:\iscsiHbaInfo)	{
			$vmkInfo = $iscsiHbaInfo | ? {$_.vmkNic -eq $vmkName}
			if (test-path variable:\vmkInfo)	{
				write-output $vmkInfo
			}
		} 			
	}
	END
	{

	}	

}

function set-vmHostLocalTime {
	<#
		.SYNOPSIS
			This function forces a time reset in the unmanaged host to prevent
			  the '"License not available to perform the operation."' error

		.DESRIPTION
			
	#>
	
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$computerIp,
		[parameter(Mandatory=$true)]
		[System.Management.Automation.PSCredential]$credential
		)
		
	# Set the time so that we don't get the '"License not available to perform the operation."' error
	# This should be a function....
	$vCenterLocal = Connect-VIServer -Server $computerIp -Credential $credential
	$vmhostLocal = get-vmhost -Server $computerIp
	$esxcliLocal = $vmhostLocal | Get-EsxCli
	$d = Get-Date
	$esxcliLocal.system.time.set($d.day, $d.hour, $d.minute, $d.month, $d.second, $d.year)
	Disconnect-VIServer -Server $vCenterLocal -Confirm:$false -Force
	Remove-Variable vmhostLocal
	Remove-Variable vCenterLocal
	Remove-Variable esxcliLocal

}

function remove-viconnection {
	<#
		.SYNOPSIS
			This function will clean up any connection created from connect-viserver

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl]$vCenterConnection
		)
	
	# Clean up any left over VI server sessions. I've seen instances where if
	try
	{
		Disconnect-VIServer $vCenterConnection -Confirm:$false
	} catch 
	{
		# No currently connected viservers (that's good).
	}

}


<#
.SYNOPSIS
Changes the iscsi LUN Qdepth settings

.DESCRIPTION
Reboot required after setting this

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function set-IscsiLunQDepth {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
	[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[int]$qDepth
	
)

	BEGIN
	{
		$module = 'iscsi_vmk'
		$moduleParameter = 'iscsivmk_LunQDepth'
	}
	PROCESS	
	{
		# List module
		#  $esxcli.system.module.parameters.list('iscsi_vmk')
		$esxcli = $vmHost | Get-EsxCli
		$esxcli.system.module.parameters.set($true,$module,"$moduleParameter=$qDepth")
		$resultsSet = $esxcli.system.module.parameters.list($module) | ? { $_.Name -eq $moduleParameter }
		Write-Output $resultsSet
	}
	END
	{

	}	

	
}

function get-IscsiLunQDepth {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
	
)

	BEGIN
	{
		$module = 'iscsi_vmk'
		$moduleParameter = 'iscsivmk_LunQDepth'
	}
	PROCESS	
	{
		
		$esxcli = $vmHost | Get-EsxCli
		$resultsSet = $esxcli.system.module.parameters.list($module) | ? { $_.Name -eq $moduleParameter }
		$obj = @()
		$obj = "" | Select-Object Host, Module, ModuleParameter, Value
		$obj.Host = $vmHost.name
		$obj.Module = $module
		$obj.ModuleParameter = $moduleParameter
		$obj.Value = $resultsSet.Value
		Write-Output $obj
	}
	END
	{

	}	

	
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
function test-DnsARecord {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$hostname
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		try {
			$a = [System.Net.Dns]::GetHostEntry($hostname).HostName | Out-Null
			Write-Host "Found DNS A for host $hostname"
		}
		catch{
			Write-Error "No DNS `'A`' record found for $hostname"
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
function test-DnsPtrRecord {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$hostname
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		try {
			$ptr = [System.Net.Dns]::GetHostEntry($hostname).AddressList[0].IPAddressToString
			Write-Host "Found DNS PTR for host $hostname ($ptr)"
			
		}
		catch{
			Write-Error "No DNS `'PTR`' record found for $hostname"
		}
	}
	END
	{

	}	

}