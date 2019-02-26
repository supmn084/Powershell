#
# Functions relating to common VMWare operations
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function get-vmHostAdvancedIscsiSettings {
	<#
		.SYNOPSIS
			This function will list advanced (global) settings for the S/W initiator HBA

		.DESRIPTION
			Does not list on individual iscsi targets
	#>

	[CmdletBinding(supportsshouldprocess=$true)]
	param (
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
		)

	BEGIN	{

	}
	
	PROCESS {
	$vmHostStorageSystemId = ($vmHost | Get-VMHostStorage).id
	$HostStorageSystem = Get-View -Id $vmHostStorageSystemId
	$iscsiHostBusAdapters = $HostStorageSystem.StorageDeviceInfo.HostBusAdapter | ? { ( ($_.model -eq 'iSCSI Software Adapter') -or ($_.model -like "*iSCSI Host Bus Adapter") ) }

	$obj = "" | Select-Object Hostname,DelayedAck, LoginTimeout
	$obj.Hostname = ($vmhost.Name)
	
	if ($iscsiHostBusAdapters) 	{
		if (($iscsiHostBusAdapters | select -First 1).Model -eq 'iSCSI Software Adapter')	{
			# s/w initiator (iscsi)
			$obj.DelayedAck = ($iscsiHostBusAdapters.AdvancedOptions | ? {$_.key -eq  'DelayedAck' }).value
			$obj.LoginTimeout = ($iscsiHostBusAdapters.AdvancedOptions | ? {$_.key -eq  'LoginTimeout' }).value
		} else {
			# h/w initiator hba
			$obj.DelayedAck = 'n/a'
			$obj.LoginTimeout = 'n/a'
		}
	} else {
		# No $iscsiHostBusAdapters present, probably has local attached storage
		$obj.DelayedAck = 'n/a'
		$obj.LoginTimeout = 'n/a'
	}

	write-output $obj
		

	
	}
	
	END {
	
	}
}

function set-vmHostAdvancedIscsiSettings {
	<#
		.SYNOPSIS
			This function will set advanced (global) settings for the S/W initiator HBA

		.DESRIPTION
			Does not operate on individual iscsi targets
	#>

	[CmdletBinding(supportsshouldprocess=$true)]
	param (
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
		)

	BEGIN	{

	}
	
	PROCESS {
	$vmHostStorageSystemId = ($vmHost | Get-VMHostStorage).id
	$HostStorageSystem = Get-View -Id $vmHostStorageSystemId
	$iscsiHostBusAdapter = $HostStorageSystem.StorageDeviceInfo.HostBusAdapter | ? {$_.model -eq 'iSCSI Software Adapter' }

	$options = New-Object VMware.Vim.HostInternetScsiHbaParamValue[] (20)	# I set to (20), didn't seem to care and it allows me to have 20 items in the array
	
	# Disable delayed ack
	$options[0] = New-Object VMware.Vim.HostInternetScsiHbaParamValue
	$options[0].key = "DelayedAck"
	$options[0].value = $false
	
	if ($vmhost.Version -match '^5.') {
		# Only ESXi 5.0 patch 2 (build 515841) and higher support changing LoginTimeout
		$options[1] = New-Object VMware.Vim.HostInternetScsiHbaParamValue
		$options[1].key = "LoginTimeout"
		$options[1].value = 30	# Wait 30 seconds until failing the login.  Very important for Equallogic login storms
	}
	
	$HostStorageSystem.UpdateInternetScsiAdvancedOptions($iscsiHostBusAdapter.Device, $null, $options)

	# Call the 'get' function so we can return results to the caller
	Write-Output (get-vmHostAdvancedIscsiSettings -vmhost $vmHost)
	}
	
	END {
	
	}
}

<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>
function disable-csgpSshNagging {
	<#
		.SYNOPSIS
			This function disables the ssh nagging on esxi 5.x

		.DESRIPTION
			
	#>
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
		)

  BEGIN	{

	}

  PROCESS	{
		Write-Verbose "Suppressing SSH Shell warning"
		try {
			$vmHost | Set-VMHostAdvancedConfiguration -name UserVars.SuppressShellWarning -Value 1 | Out-Null
		} catch {
			Write-Error "Unable to set UserVars.SuppressShellWarning 1"
			exit
		}
	}
  END	{

	}	

}

<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>
function set-csgpsyslog {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[string]$syslogServer
	)

  BEGIN	{

	}

  PROCESS	{
		Write-Verbose "Setting Syslog servers"
		try {
			$vmhost | Get-AdvancedSetting -name syslog.global.loghost | Set-AdvancedSetting -value $syslogServer -confirm:$false | Out-Null
		} catch {
			Write-Error "Unable to set syslog server"
			exit
		}
		
	    try {
			Write-Verbose "Restarting Syslog service"
			$esxcli = $vmHost | Get-EsxCli
			$result = $esxcli.system.syslog.reload()
	    	
		} catch {
			Write-Error "Unable to restart the syslog service"
		}
		
		 #Open the firewall on the ESX Host to allow syslog traffic
	    try { 
			Write-Verbose "Opening up firewall to allow outbound syslog"
			$result = $vmHost | Get-VMHostFirewallException -Name 'syslog' | set-VMHostFirewallException -Enabled:$true
		} catch {
			Write-Error "Unable to open the syslog port in the firewall"
		}
	}
  END	{

	}	

}

<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>
function set-csgpNtpServers {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[array]$ntpServers
	)

  BEGIN	{

	}

  PROCESS	{
		# Clear out the existing NTP servers, if any
		$ntpServersExisting = Get-VMHostNtpServer -VMHost $vmHost 
		if ($ntpServersExisting)	{
			foreach ($ntpServer in $ntpServersExisting)	{
				Remove-VMHostNtpServer -VMHost $vmHost -NtpServer $ntpServer -Confirm:$false 
			}
		}
		
		foreach ($ntpServer in $ntpServers)	{
			Write-Verbose "Adding NTP $ntpServer"
			$result = Add-VmHostNtpServer -VMHost $vmHost -NtpServer $ntpServer -Confirm:$false 
		}
		
		# Start the NTPd service
		$ntpSvcObj = Get-VmHostService -VMHost $vmhost -Verbose:$false | ? { $_.key -eq "ntpd"}
		sleep 3
		if ($ntpSvcObj.Running -eq $true)	{
			# Stop and restart ntpd
			$resultRestart = Restart-VMHostService -HostService $ntpSvcObj -Confirm:$false
		}
		
		else {
			# It's not running yet
			$resultStart = Start-VMHostservice -HostService $ntpSvcObj -Confirm:$false
		}
		
		# Set to start automatically
		$resultSet = Set-VMHostService -HostService $ntpSvcObj -Policy Automatic -Confirm:$false

	}
  END	{

	}	

}

<#
.SYNOPSIS
set-csgpStorageIoOperationLimit changes the I/O path switching on the device
Version 1.00

.DESCRIPTION
for -satp you may use: VMW_SATP_EQL (eql), VMW_SATP_ALUA_CX (VNX)


.EXAMPLE
$vmhost | set-csgpStorageIoOperationLimit -iolimit 1 -satp VMW_SATP_ALUA_CX

.EXAMPLE
$vmhost | set-csgpStorageIoOperationLimit -iolimit 1 -satp VMW_SATP_EQL

#>
function set-csgpStorageIoOperationLimit {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[int]$iolimit,
		
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False,
			HelpMessage='VMW_SATP_EQL,VMW_SATP_ALUA_CX')]
		[ValidateNotNullOrEmpty()]
		[string]$satp
	)
	
	BEGIN	
	{

	}

	PROCESS
	{
		$cnt = 0
		Write-Verbose "Connecting to the EsxCli provider on $($vmHost.name)"
		$esxcli = $vmHost | Get-EsxCli
		
		# Get devices that match the storagae array type plugin (satp)
		$deviceList = $esxcli.storage.nmp.device.list() | ? {$_.StorageArrayType -eq $satp }
		try
		{
			if (Test-Path variable:\deviceList)	{
				foreach ($device in $deviceList)	{
					$naaId = $device.device 
					try {	
						Write-Verbose "Setting device $naaId to $iolimit IOPS"
						$result = $esxcli.storage.nmp.psp.roundrobin.deviceconfig.set($null,$null,$naaId,$iolimit,'iops',$null)
					} catch {
						Write-Verbose "Device $naaId does not suport RR.  $($device.PathSelectionPolicy), $($device.DeviceDisplayName)"
					}
				}	
			}
		} 
		catch
		{
			Write-Verbose "Unable to find any devices matching a SATP plugin $satp"
		}
		
		$vmHost | get-csgpStorageIoOperationLimit -satp $satp
	}
	END
	{
		
	}	
}

<#
.SYNOPSIS
get-csgpStorageIoOperationLimit lists the IOOperationLimit on each device
Version 1.00

.DESCRIPTION
for -satp you may use: VMW_SATP_EQL (eql), VMW_SATP_ALUA_CX (VNX)

.EXAMPLE
$vmhost | get-csgpStorageIoOperationLimit  -satp VMW_SATP_ALUA_CX

.EXAMPLE
$vmhost | get-csgpStorageIoOperationLimit  -satp VMW_SATP_EQL

#>
function get-csgpStorageIoOperationLimit {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False,
			HelpMessage='VMW_SATP_EQL,VMW_SATP_ALUA_CX')]
		[ValidateNotNullOrEmpty()]
		[string]$satp
	)
	
	BEGIN	
	{

	}

	PROCESS
	{
		Write-Verbose "Connecting to the EsxCli provider on $($vmHost.name)"
		$esxcli = $vmHost | Get-EsxCli
		
		# Get devices that match the storagae array type plugin (satp)
		$deviceList = $esxcli.storage.nmp.device.list() | ? {$_.StorageArrayType -eq $satp }
		
		try 
		{
			if (Test-Path variable:\deviceList)	{
				foreach ($device in $deviceList)	{
					$naaId = $device.device 
					try {	
						$result = $esxcli.storage.nmp.psp.roundrobin.deviceconfig.get($naaId)
						Write-Output "$($vmhost.name)|$($result.device)|IOOperationLimit: $($result.IOOperationLimit)"
					} catch {
						Write-Verbose "Device $naaId does not suport RR.  $($device.PathSelectionPolicy), $($device.DeviceDisplayName)"
					}
				}	
			}
		}
		catch
		{
			Write-Verbose "Unable to find any devices matching a SATP plugin $satp"
		}
	}
	END
	{

	}	

}

<#
.SYNOPSIS
set-csgpDefaultPSP changes the default PSP for a given SATP
Version 1.00

.DESCRIPTION
for -psp you may use: VMW_PSP_FIXED (eql), VMW_PSP_FIXED_AP (VNX), VMW_PSP_RR (EQL,VNX)
for -satp you may use: VMW_SATP_EQL (eql), VMW_SATP_ALUA_CX (VNX)


.EXAMPLE
$vmhost | set-csgpDefaultPSP -psp VMW_PSP_RR -satp VMW_SATP_ALUA_CX

.EXAMPLE
$vmhost | set-csgpDefaultPSP -psp VMW_PSP_RR -satp VMW_SATP_EQL

#>
function set-csgpDefaultPSP {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$satp,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$psp
	)
	
	BEGIN	
	{

	}

	PROCESS
	{
		Write-Verbose "Connecting to the EsxCli provider on $($vmHost.name)"
		$esxcli = $vmHost | Get-EsxCli
		
		try
		{
			#PS C:\> $esxCli.storage.nmp.satp.list()
			#
			#DefaultPSP                 Description                Name
			#----------                 -----------                ----
			#VMW_PSP_FIXED              Supports EqualLogic arrays VMW_SATP_EQL
			#VMW_PSP_FIXED_AP           Supports EMC CX that use the ALUA pr... VMW_SATP_ALUA_CX
			#VMW_PSP_MRU                Placeholder (plugin not... VMW_SATP_MSA
			#VMW_PSP_MRU                Placeholder (plugin not... VMW_SATP_ALUA
			#VMW_PSP_MRU                Placeholder (plugin not... VMW_SATP_DEFAULT_AP
			#VMW_PSP_FIXED              Placeholder (plugin not... VMW_SATP_SVC
			#VMW_PSP_FIXED              Placeholder (plugin not... VMW_SATP_INV
			#VMW_PSP_FIXED              Placeholder (plugin not... VMW_SATP_EVA
			#VMW_PSP_RR                 Placeholder (plugin not... VMW_SATP_ALUA_CX
			#VMW_PSP_RR                 Placeholder (plugin not... VMW_SATP_SYMM
			#VMW_PSP_MRU                Placeholder (plugin not... VMW_SATP_CX
			#VMW_PSP_MRU                Placeholder (plugin not... VMW_SATP_LSI
			#VMW_PSP_FIXED              Supports non-specific a... VMW_SATP_DEFAULT_AA
			#VMW_PSP_FIXED              Supports direct attache... VMW_SATP_LOCAL
			# Set default path selection policy
			$esxcli.storage.nmp.satp.set($null,$psp,$satp)
		}
		catch
		{
			Write-Error "Unable to set default PSP on SATP for host $($vmhost.name)"
		}
		
		
	}
	END
	{

	}	

}

<#
.SYNOPSIS
set-csgpLunPsp changes all iScsi paths to the psp you specify
Version 1.00

.DESCRIPTION
for -psp you may use: VMW_PSP_FIXED (eql), VMW_PSP_FIXED_AP (VNX), VMW_PSP_RR (EQL,VNX)
for -satp you may use: VMW_SATP_EQL (eql), VMW_SATP_ALUA_CX (VNX)


.EXAMPLE
$vmhost | set-csgpLunPsp -psp VMW_PSP_RR -satp VMW_SATP_ALUA_CX

.EXAMPLE
$vmhost | set-csgpLunPsp -psp VMW_PSP_RR -satp VMW_SATP_EQL

#>
function set-csgpLunPsp {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$psp,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$satp
	)
	
	BEGIN	
	{

	}

	PROCESS
	{
		Write-Verbose "Connecting to the EsxCli provider on $($vmHost.name)"
		$esxcli = $vmHost | Get-EsxCli
		
		# Get devices that match the storagae array type plugin (satp)
		$deviceList = $esxcli.storage.nmp.device.list() | ? {$_.StorageArrayType -eq $satp }
		
		try 
		{
			if (Test-Path variable:\deviceList)	{
				# we have one or more devices that match the satp
				foreach ($device in $deviceList)	{
					$naaId = $device.device 
					try {	
						Write-Verbose "Setting device $naaId to use $psp"
						$result = $esxcli.storage.nmp.device.set($null, $naaId, $psp)
					} catch {
						Write-Verbose "Device $naaId does not suport RR.  $($device.PathSelectionPolicy), $($device.DeviceDisplayName)"
					}
				}
			} 
			
		}
		catch
		{
			Write-Verbose "No devices were found that support SATP $satp"
		}
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Enable ssh on the EXi host
Version 1.00

.DESCRIPTION

.EXAMPLE
$vmhost | enable-csgpssh

#>
function enable-csgpEsxiShell {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHost
)

	BEGIN
	{

	}
	PROCESS	
	{
		$vmhost | get-vmhostservice | ? {$_.key -eq 'TSM-SSH' } | set-VMHostService -Policy Automatic
		$result = $vmhost | get-vmhostservice | ? {$_.key -eq 'TSM-SSH' } | Start-VMHostService
		Write-Output $result		
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Assigns a singular ESXi license to a singular VMhost
Version 1.00

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE

#>
function set-csgpVMHostLicense {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$hostname,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$licenseKey
)

	BEGIN
	{

	}
	PROCESS	
	{		
		$objServiceInstance = Get-View -Id ServiceInstance -Property Content.LicenseManager 
		$objLicenseManager = Get-View -Id $objServiceInstance.Content.LicenseManager -Property LicenseAssignmentManager
		$objLicenseAssignmentManager = Get-View -Id $objLicenseManager.LicenseAssignmentManager
		$VMHostView = Get-View -ViewType "HostSystem" -Filter @{Name=$hostname} -Property Config.Host
		$result = $objLicenseAssignmentManager.UpdateAssignedLicense($VMHostView.Config.Host.Value, $licenseKey, $hostname)
		$obj = @()
		$obj = "" | Select-Object Hostname,LicenseType
		$obj.hostname = $hostname
		$obj.LicenseType = $result.name
		Write-output $obj
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Sets the vSwitch security settings for Promiscuous, MAC address change, Forged Transmits

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE


#>
function set-csgpvSwitchSecurity {
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
		
		write-verbose "Configuring vSwitch Security settings for all standard vSwitches"

		$vswitchName = $vswitch.name
		$vmHost = Get-VMHost $vSwitch.vmhost.name
		$hostview = get-vmhost $vmhost | Get-View
		$ns = Get-View -Id $hostview.ConfigManager.NetworkSystem
		$vsConfig = $hostview.Config.Network.Vswitch | Where-Object { $_.Name -eq $vswitchName }
		
		$vsSpec = $vsConfig.Spec
		$vsSpec.Policy.NicTeaming.FailureCriteria.checkBeacon = $false
		$vsSpec.Policy.Security.AllowPromiscuous = $False
		$vsSpec.Policy.Security.forgedTransmits = $False
		$vsSpec.Policy.Security.macChanges = $False
		
		$ns.UpdateVirtualSwitch( $VSwitchName, $vsSpec)

	}
	END
	{

	}	
}

<#
.SYNOPSIS
Allows a login to ESX(i) using ssh, via Putty plink. 

.DESCRIPTION
Use this as a last resort.  Often PowerCli or vCLI will have the commands
that you need

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE


#>
function invoke-plinkesx {
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmhost,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[System.Management.Automation.PSCredential]$cred,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$plinkExe,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$plinkCmd
		
		)
		
	
	$vmhostName = $vmhost.name

		 
	Write-Host "Setting up Putty Connections" -ForegroundColor Cyan
	# Converting ESX Credential Password to clear text for use by Putty/Plink
	$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cred.Password)
	$ESXClearPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
	[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
	 
	$plinkUserName = $cred.username.trimstart('\')
	
	# if this is the first time plink connects to the host we'll get a prompt
	# for accepting the remote fingerprint.  Here will will automatically
	# accept the fingerprint.  Do not run any important comamnds here, we just 
	# run 'date'
	
	# Need to run this with -batch and figure out how tot parse for:
	# 'host key is not cached in the registry'
	[Array]$arguments = "-pw", $ESXClearPwd, "$plinkUserName@$vmhostname", 'echo'; 
	"Y" | & $plinkExe $arguments;  # Accept the fingerprint

	[Array]$arguments = "-batch", "-pw", $ESXClearPwd, "$plinkUserName@$vmhostname", $plinkCmd;
	& $plinkExe $arguments;  # Accept the fingerprint
	Remove-Variable ESXClearPwd
	#Remove-Variable -Name PlinkLaunch

}

function Get-VaaiUnmapStatus
{
  <#
  .SYNOPSIS
  will list out all the VMFS volumes on the host and will display their VAAI unmap status
  .DESCRIPTION

Example Output:
	
DataStoreName       : DCVMHTST904-DEFAULTVMFS01
DataStoreUrl        : /vmfs/volumes/500e8776-6196bb40-b00a-f4ce46899404/
DatastoreUUID       : 500e8776-6196bb40-b00a-f4ce46899404
DataStoreNaaId      : naa.600508b1001030364235363534300e00
DataStoreVaaiStatus : unknown
SanDeleteStatus     : unsupported

DataStoreName       : ESX-USDC-LAB-DCAPPTST250-GOLD-S-001
DataStoreUrl        : /vmfs/volumes/54135b8f-4ab00cbe-f8b5-f4ce46899400/
DatastoreUUID       : 54135b8f-4ab00cbe-f8b5-f4ce46899400
DataStoreNaaId      : naa.6006016060e0360095fabe88bd3ae411
DataStoreVaaiStatus : supported
SanDeleteStatus     : supported


  .EXAMPLE
  get-vmhost blah | get-VaaiUnMapStatus
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
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmhost
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$report = @()
		$esxcli = $vmhost | Get-EsxCli
		
		# All the datastores this host sees
		$datastores = $vmhost | get-datastore
		
		foreach ($ds in $datastores)
		{
			
			# skip datastoers that are not "local".
			# 	vSphere 5.1 we use $datastores[1].ExtensionData.Summary.MultipleHostAccess
			# 	vshere 5.5 we can use http://pubs.vmware.com/vsphere-55/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc%2Fvim.host.VmfsVolume.html  "local"
			
			# Write-Verbose "$($ds.Name) $($ds.ExtensionData.Summary.MultipleHostAccess)"
			
			if ($ds.ExtensionData.Summary.MultipleHostAccess -eq $False)
			{
				write-verbose "$($ds.name) is a local datastore, does not support vaai"
			}
			
			$dsUrl = $ds.ExtensionData.Info.Url
			
			# Remove the ds:// in the url.
			# now looks like /vmfs/volumes/52f01dff-a2c09aa6-865c-b4b52f6ef3a8/
			# vmkfstools does not mind the traling slash
			$dsUrl = $dsUrl -replace "ds://", ""
			
			$vmfsExtentCount = ($ds.Extensiondata.info.vmfs.Extent | measure-object).count
			if ($vmfsExtentCount -gt 1)
			{
				Write-warning "Datastore $($ds.name) has more than 1 extent, skipping vaai unmap..."
				continue
			}
			else
			{
				$naaId = ($ds.Extensiondata.info.vmfs.Extent[0]).DiskName
			}
			
			
			# Does the back end array support VAAI unmap?
			$SanDeleteStatus = $esxcli.storage.core.device.vaai.status.get($naaId).DeleteStatus
			if (! $SanDeleteStatus -eq 'Supported')
			{
				Write-Warning "SAN array backing Datastore $($ds.name) does not support Deletestatus..."
				continue
			}
			
			
			$vaaiStatus = $esxcli.storage.core.device.list($naaId).VaaiStatus
			$DatastoreUUID = $ds.ExtensionData.info.vmfs.uuid
			
			if ($vaaiStatus -eq 'supported')
			{
				# Custom Object
				$obj = New-Object PSObject
				$obj | Add-Member Noteproperty -Name DataStoreName -value $ds.name
				$obj | Add-Member Noteproperty -Name DataStoreUrl -value $dsUrl
				$obj | Add-Member NoteProperty -Name DatastoreUUID -Value $DatastoreUUID
				$obj | Add-Member Noteproperty -Name DataStoreNaaId -value $naaId
				$obj | Add-Member Noteproperty -Name DataStoreVaaiStatus -value $vaaiStatus
				$obj | Add-Member Noteproperty -Name SanDeleteStatus -Value $SanDeleteStatus
				$obj | Add-Member Noteproperty -Name VmHost -Value $vmhost				
				
				$report += $obj
				
			}
			else
			{
				#				$obj = New-Object PSObject
				#				$obj | Add-Member Noteproperty -Name DataStoreName -value $ds.name
				#				$obj | Add-Member Noteproperty -Name DataStoreUrl -value $dsUrl
				#				$obj | Add-Member NoteProperty -Name DatastoreUUID -Value $DatastoreUUID
				#				$obj | Add-Member Noteproperty -Name DataStoreNaaId -value $naaId
				#				$obj | Add-Member Noteproperty -Name DataStoreVaaiStatus -value $vaaiStatus
				#				$obj | Add-Member Noteproperty -Name SanDeleteStatus -Value $SanDeleteStatus
				#				$obj | Add-Member Noteproperty -Name VmHost -Value $vmhost
				# Write-Warning "Datastore $($ds.name) does not support vaai ($vaaiStatus)"
				# $report += $obj
				continue
			}
			
			
		}
		
		Write-Output $report
		
	}
	
	End
	{
		
	}
}

function invoke-VaaiUnmap
{
  <#
  .SYNOPSIS
  Will start the vaai unmap process on a given datastore UUID and host
  .DESCRIPTION
  You must be connected to vCenter before running this cmdlet
	
  .EXAMPLE
   get-vmhost blah | get-VaaiUnMapStatus | ? { $_.DataStoreVaaiStatus -ne 'unknown' } | invoke-VaaiUnmap
  .EXAMPLE
   get-vmhost blah | invoke-VaaiUnmap -DataStoreUUID 54135b8f-4ab00cbe-f8b5-f4ce46899400
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmhost,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$DataStoreUUID
	)
	
	begin
	{
		# see if we can avoid the 300 second default timeout ("Error occured: The operation has timed out")
		$powerCliConfig = Set-PowerCLIConfiguration -Scope Session -WebOperationTimeoutSeconds -1 -Confirm:$false
	}
	
	process
	{
		$Error.clear()
		$report = @()
		$obj = @()
		
		$esxcli = $vmhost | Get-EsxCli
		$vmfsVolumeName = ($esxcli.storage.vmfs.extent.list() | ? { $_.VMFSUUID -eq $DataStoreUUID }).VolumeName
		
		$startTime = Get-Date
		
		try
		{
			$result = $esxcli.storage.vmfs.unmap(1000, $null, $DataStoreUUID)
			$notes = $null
		}
		catch
		{
			$notes = "Error occured: $_.message"
			$result = 'Fail'
		}
		
		$endTime = get-date
		$totalMinutes = [math]::Round((New-TimeSpan -start $startTime -end $endTime).totalminutes, 0)
		$obj = "" | Select-Object VmHost, VMFS, UUID, Result, Minutes, Notes
		$obj.VmHost = $vmhost.name
		$obj.VMFS = $vmfsVolumeName
		$obj.UUID = $DataStoreUUID
		$obj.Result = $result
		$obj.Minutes = $totalMinutes
		$obj.Notes = $notes
		$report += $obj
		
		Write-Output $report
	}
	
	End
	{
		
	}
}

<#
.SYNOPSIS
Tags new datastores in the CoStar vCenter


.DESCRIPTION
Datastores must be tagged with certain properties so that the deployment script knows where to place new VMs


.EXAMPLE
(get-datastore ESX-USVI-PRDINT-102-GOLD-00*) | set-csgpDatastoreTag -ITEnvironment PRD -ITSubEnvironment 'Internal Production' -failuredomain Auto-Select -ServerRole WEBAPP

#>

function set-csgpDatastoreTag {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$datastore,
	[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("DEV", "TST", "DEVTST", "PRD", "BAT", "DR")]
	[string]$ITEnvironment,
	[parameter(Mandatory = $False, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("External Customer Facing", "Internal Production", "Stand-Alone", "Integrated", "Disaster Recovery")]
	[string]$ITSubEnvironment,
	[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("FD-A","FD-B","Auto-Select")]
	[string]$failuredomain,
	[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
	[ValidateNotNullOrEmpty()]
	[ValidateSet("WEBAPP","SQL")]
	[string]$ServerRole
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		foreach ($ds in $datastore)
		{
			
			# Any existing tags that will be updated will first be removed.  Any additional tags not set here will still be maintained
			
			$dsCurrentTags = $ds | get-tagAssignment
			
			# ITEnvironment
			$tag = get-tag -Category ITEnvironment -Name $ITEnvironment -verbose:$false
			try
			{
				$ds | Get-TagAssignment | ? { $_.tag.category.name -eq 'ITEnvironment' } | Remove-TagAssignment -confirm:$false
			}
			catch { }
			New-TagAssignment -entity $ds -tag $tag -verbose:$false | Out-Null
			
			# ITSubEnvironment
			if ($ITSubEnvironment)
			{
				
				$tag = get-tag -Category ITSubEnvironment -Name $ITSubEnvironment -verbose:$false
				try
				{
					$ds | Get-TagAssignment | ? { $_.tag.category.name -eq 'ITSubEnvironment' } | Remove-TagAssignment -confirm:$false
				}
				catch { }
				New-TagAssignment -entity $ds -tag $tag -verbose:$false | Out-Null
			}
			
			# ServerRole
			$tag = get-tag -Category ServerRole -Name $ServerRole -verbose:$false
			try
			{
				$ds | Get-TagAssignment | ? { $_.tag.category.name -eq 'ServerRole' } | Remove-TagAssignment -confirm:$false
			}
			catch { }
			New-TagAssignment -entity $ds -tag $tag -verbose:$false | Out-Null
			
			# FailureDomain
			$tag = get-tag -Category FailureDomain -Name $failuredomain -verbose:$false
			try
			{
				$ds | Get-TagAssignment | ? { $_.tag.category.name -eq 'FailureDomain' } | Remove-TagAssignment -confirm:$false
			}
			catch { }
			New-TagAssignment -entity $ds -tag $tag -verbose:$false | Out-Null
			
		}
	}
	END
	{
		
	}
	
}




<#
.SYNOPSIS  Returns configuration changes for a VM
.DESCRIPTION The function will return the list of configuration changes
    for a given Virtual Machine
.NOTES  Author:  William Lam
.NOTES  Site:    www.virtuallyghetto.com
.NOTES  Comment: Modified example from Lucd's blog post http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/
.PARAMETER Vm
  Virtual Machine object to query configuration changes
.PARAMETER Hour
  The number of hours to to search for configuration changes, default 8hrs
.EXAMPLE
  PS> Get-VMConfigChanges -vm $VM
.EXAMPLE
  PS> Get-VMConfigChanges -vm $VM -hours 8
#>

Function Get-VMConfigChanges
{
	param ($vm, $hours = 8)
	
	# Modified code from http://powershell.com/cs/blogs/tips/archive/2012/11/28/removing-empty-object-properties.aspx
	Function prettyPrintEventObject($vmChangeSpec, $task)
	{
		$hashtable = $vmChangeSpec |
		Get-Member -MemberType *Property |
		Select-Object -ExpandProperty Name |
		Sort-Object |
		ForEach-Object -Begin {
			[System.Collections.Specialized.OrderedDictionary]$rv = @{ }
		} -process {
			if ($vmChangeSpec.$_ -ne $null)
			{
				$rv.$_ = $vmChangeSpec.$_
			}
		} -end { $rv }
		
		# Add in additional info to the return object (Thanks to Luc's Code)
		$hashtable.Add('VMName', $task.EntityName)
		$hashtable.Add('Start', $task.StartTime)
		$hashtable.Add('End', $task.CompleteTime)
		$hashtable.Add('State', $task.State)
		$hashtable.Add('User', $task.Reason.UserName)
		$hashtable.Add('ChainID', $task.EventChainId)
		
		# Device Change
		foreach ($deviceChange in $vmChangeSpec.DeviceChange)
		{
			if (Test-Path $deviceChange)
			{
				if ($deviceChange.Device -ne $null)
				{
					$hashtable.Add('Device', $deviceChange.Device.GetType().Name)
					$hashtable.Add('Operation', $deviceChange.Operation)
				}
			}
			
			
		}
		$newVMChangeSpec = New-Object PSObject
		$newVMChangeSpec | Add-Member ($hashtable) -ErrorAction SilentlyContinue
		return $newVMChangeSpec
	}
	
	# Modified code from Luc Dekens http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/
	$tasknumber = 999 # Windowsize for task collector
	$eventnumber = 100 # Windowsize for event collector
	
	$report = @()
	$taskMgr = Get-View TaskManager
	$eventMgr = Get-View eventManager
	
	$tFilter = New-Object VMware.Vim.TaskFilterSpec
	$tFilter.Time = New-Object VMware.Vim.TaskFilterSpecByTime
	$tFilter.Time.beginTime = (Get-Date).AddHours(- $hours)
	$tFilter.Time.timeType = "startedTime"
	$tFilter.Entity = New-Object VMware.Vim.TaskFilterSpecByEntity
	$tFilter.Entity.Entity = $vm.ExtensionData.MoRef
	$tFilter.Entity.Recursion = New-Object VMware.Vim.TaskFilterSpecRecursionOption
	$tFilter.Entity.Recursion = "self"
	
	$tCollector = Get-View ($taskMgr.CreateCollectorForTasks($tFilter))
	
	$dummy = $tCollector.RewindCollector
	$tasks = $tCollector.ReadNextTasks($tasknumber)
	
	while ($tasks)
	{
		$tasks | where { $_.Name -eq "ReconfigVM_Task" } | % {
			$task = $_
			$eFilter = New-Object VMware.Vim.EventFilterSpec
			$eFilter.eventChainId = $task.EventChainId
			
			$eCollector = Get-View ($eventMgr.CreateCollectorForEvents($eFilter))
			$events = $eCollector.ReadNextEvents($eventnumber)
			while ($events)
			{
				$events | % {
					$event = $_
					switch ($event.GetType().Name)
					{
						"VmReconfiguredEvent" {
							$event.ConfigSpec | % {
								$report += prettyPrintEventObject $_ $task
							}
						}
						Default { }
					}
				}
				$events = $eCollector.ReadNextEvents($eventnumber)
			}
			$ecollection = $eCollector.ReadNextEvents($eventnumber)
			# By default 32 event collectors are allowed. Destroy this event collector.
			$eCollector.DestroyCollector()
		}
		$tasks = $tCollector.ReadNextTasks($tasknumber)
	}
	
	# By default 32 task collectors are allowed. Destroy this task collector.
	$tCollector.DestroyCollector()
	
	$report
}