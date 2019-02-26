#
#  We are using this module to automatically connect to EMC iSCSI targets.
#  Install this module on a local host using the following script:
# "\\Dcdmpprd500\apps\AutoInstalls\SAN\Install_emc_iscsi_scripts.bat"

# Copyright (c) 2011 Code Owls LLC, All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this 
# software and associated documentation files (the "Software"), to deal in the Software without 
# restriction, including without limitation the rights to use, copy, modify, merge, publish, 
# distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the  
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or 
# substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF 
# CONTRACT, TORT OR OTHERWISE, ARISING FROM, # OUT OF OR IN CONNECTION WITH THE SOFTWARE 
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# 
# http://www.opensource.org/licenses/mit-license.php
#  
# PowerShell module for iSCSI management
#
# author:
#	jim christopher <jimchristopher@gmail.com>
#
# notes:
#
#Target Mappings:
#    <Target Lun> is the LUN value the target uses to expose the LUN.
#                 It must be in the form 0x0123456789abcdef
#    <OS Bus> is the bus number the OS should use to surface the LUN
#    <OS Target> is the target number the OS should use to surface the LUN
#    <OS LUN> is the LUN number the OS should use to surface the LUN
#
#CHAP secrets, CHAP passwords and IPSEC preshared keys can be specified as
#a text string or as a sequence of hexadecimal values. The value specified on
#the command line is always considered a string unless the first two characters
#0x in which case it is considered a hexadecimal value.
#
#For example 0x12345678 specifies a 4 byte secret
#
#All numerical values are assumed decimal unless preceeded by 0x. If
#preceeded by 0x then value is assumed to be hex
#
#iscsicli can also be run in command line mode where iscsicli commands
#can be entered directly from the console. To enter command line
#mode, just run iscsicli without any parameters


###########################################################
## flags and enumerations

#Payload Id Type:
#    ID_IPV4_ADDR is      1 - Id format is 1.2.3.4
#    ID_FQDN is           2 - Id format is ComputerName
#    ID_IPV6_ADDR is      5 - Id form is IPv6 Address
#
$payloadIPV4	 	= 1;
$payloadFQDN 		= 2;
$payloadIPV6		= 5;

#Security Flags:
#    TunnelMode is          0x00000040
#    TransportMode is       0x00000020
#    PFS Enabled is         0x00000010
#    Aggressive Mode is     0x00000008
#    Main mode is           0x00000004
#    IPSEC/IKE Enabled is   0x00000002
#    Valid Flags is         0x00000001
#
$securityTunnelMode			= 0x40;
$securityTransportMode		= 0x20;
$securityPFSEnable			= 0x10;
$securityAggressiveMode		= 0x08;
$securityMainMode			= 0x04;
$securityIPSECIKEEnabled	= 0x02;
$securityValidFlags			= 0x01;

#Login Flags:
#    ISCSI_LOGIN_FLAG_REQUIRE_IPSEC                0x00000001
#        IPsec is required for the operation
#
#    ISCSI_LOGIN_FLAG_MULTIPATH_ENABLED            0x00000002
#        Multipathing is enabled for the target on this initiator
#
$loginRequireIPSEC			= 0x01;
$loginMultipathEnabled		= 0x02;

#AuthType:
#    ISCSI_NO_AUTH_TYPE = 0,
#        No iSCSI in-band authentication is used
#
#    ISCSI_CHAP_AUTH_TYPE = 1,
#        One way CHAP (Target authenticates initiator is used)
#
#    ISCSI_MUTUAL_CHAP_AUTH_TYPE = 2
#        Mutual CHAP (Target and Initiator authenticate each other is used)
#
$authTypeNone		= 0;
$authTypeChap		= 1;
$authTypeMutualChap	= 2;

#Target Flags:
#    ISCSI_TARGET_FLAG_HIDE_STATIC_TARGET            0x00000002
#        If this flag is set then the target will never be reported unless it
#        is also discovered dynamically.
#
#    ISCSI_TARGET_FLAG_MERGE_TARGET_INFORMATION      0x00000004
#        If this flag is set then the target information passed will be
#        merged with any target information already statically configured for
#        the target
#
$targetHideStaticTarget		= 0x02;
$targetMergeTargetInfo		= 0x04;

###########################################################
## cmdlets

#iscsicli AddTarget <TargetName> <TargetAlias> <TargetPortalAddress>
#                           <TargetPortalSocket> <Target flags>
#                           <Persist> <Login Flags> <Header Digest> <Data Digest> 
#                           <Max Connections> <DefaultTime2Wait>
#                           <DefaultTime2Retain> <Username> <Password> <AuthType>
#                           <Mapping Count> <Target Lun> <OS Bus> <Os Target> 
#                           <OS Lun> ...
#
#iscsicli QAddTarget <TargetName> <TargetPortalAddress>
#
function Add-Target
{
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)]
		[Alias("Name")]
		[string]		
		# the name of the target
		$targetName,

		[Parameter(Mandatory=$true)]
		[Alias("Address")]
		[string]
		# the IP or DNS address of the target portal
		$targetPortalAddress
	)
	process
	{
		& iscsicli qaddtarget $targetName, $targetPortalAddress;
	}
}

#iscsicli RemoveTarget <TargetName> 
#
#RemovePersistentTarget <Initiator Name> <TargetName>
#                       <Initiator Port Number>
#                       <Target Portal Address>
#                       <Target Portal Socket>
#
function Remove-Target
{
<#
	This command will remove a target from the list of persisted targets.

Boot Configuration Known Issues (Windows Server 2003 Boot Initiator)
The Microsoft iSCSI Software Initiator boot version GUI does not allow you to view which adapter is set to boot. In order 

to determine which adapter the system is set to boot with, you can use the following command:
 From a command prompt  type �iscsibcg /showibf� to find the MAC address of the boot adapter 
 Then run the command �ipconfig /all�  
 Compare the MAC address of the adapter to those listed with ipconfig /all 

MPIO Failover in an iSCSI boot configuration using the Microsoft iSCSI Software Initiator

In Fail Over Only, no load balancing is performed. The primary path functions as the active path and all other paths are 

standby paths. The active path is used for sending all I/O. If the active path fails,  one of the standby paths  becomes 

the active path.   When the  formerly active path is reconnected, it becomes a standby path and  a "failback" does not 

occur.   This behavior is due to Media Sensing is disabled by default in the boot version of the Microsoft iSCSI Software 

Initiator and is by design.  However, the registry key can be changed to enable fail back.  For more information, please 

see
     
For more information: 
239924  How to disable the Media Sensing feature for TCP/IP in Windows
http://support.microsoft.com/default.aspx?scid=kb;EN-US;239924   
#>
	[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='high')]
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
		[Alias("Name")]
		[string]
		# the name of the target to remove
		$targetName,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias("Address")]
		[string]
		# the IP or DNS address of the target portal
		$targetPortalAddress,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias('Port')]
		[int]
		#the TCP port number of the target portal. Typically this is 3260, which is the well-known port number defined for use by iSCSI.
		$TargetPortalSocket = 3260,
		
		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias( "InitiatorInstanceName" )]
		[string]
		#the name of the initiator via which the SendTargets operation is performed. If not specified then the initiator used is selected by the iSCSI initiator service.
		$InitiatorName, 

		[Parameter(ValueFromPipelineByPropertyName=$true)]
		[string]
		#is the physical port number on the initiator via which the SendTargets operation is performed. If not specified then the kernel mode initiator driver chooses the initiator port used.
		$InitiatorPort = '*',		
		
		[Parameter()]
		[switch]
		# specify to remove a persistent connection
		$persist,
		
		[Parameter()]
		[switch]
		# specify to bypass standard PowerShell confirmation procedures
		$force		
	)
	
	process
	{
		Write-Verbose "remove-target ...";
		Write-Verbose "  TargetName: $targetName";
		Write-Verbose "  TargetPortalAddress: $targetPortalAddress";
		Write-Verbose "  TargetPortalSocket: $targetPortalSocket";
		Write-Verbose "  InitiatorInstanceName: $InitiatorName";
		Write-Verbose "  InitiatorPort: $initiatorPort";
		Write-Verbose "  Persist: $persist";
		Write-Verbose "  Force: $force";

		if( -not ( $force -or $pscmdlet.ShouldProcess( $targetName, 'Remove iSCSI target' ) ) )
		{
			return;
		}
		if( $persist -and $InitiatorName )
		{
			$iscsi = "iscsicli removepersistenttarget $InitiatorName $targetName $InitiatorPort $targetPortalAddress $TargetPortalSocket"
			Write-Verbose $iscsi;
			invoke-expression $iscsi
		}
		else
		{
			$iscsi = "iscsicli removetarget $targetName";
			Write-Verbose $iscsi;
			invoke-expression $iscsi
		}
		
	}
}

#iscsicli AddTargetPortal <TargetPortalAddress> <TargetPortalSocket> 
#                         [HBA Name] [Port Number]
#                         <Security Flags>
#                         <Login Flags> <Header Digest> <Data Digest> 
#                         <Max Connections> <DefaultTime2Wait>
#                        <DefaultTime2Retain> <Username> <Password> <AuthType>
#
#iscsicli QAddTargetPortal <TargetPortalAddress>
#                          [CHAP Username] [CHAP Password]
#
function Add-TargetPortal
{
<#
This command will add a target portal to the list of persisted target portals. The iSCSI initiator service will perform a 

SendTargets operation to each target portal in the list whenever the service starts and whenever a full refresh of the 

target list is requested. 

#>
	#[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)]
		[Alias("Address")]
		[string]
		# the IP or DNS address of the target portal.
		$targetPortalAddress,
		
		[Parameter()]
		[string]
		#Username is the string that should be used as the CHAP username when logging into the target. By specifying * for this parameter, the iSCSI initiator service will use the initiator node name as the CHAP username.
		$username,
		
		[Parameter()]
		[string]
		#Password is the string that should be used as the target�s CHAP secret when logging into the target. The initiator will use this secret to compute a hash value based on the challenge sent by the target. 
		$password
	)
	process
	{
		if( $username )
		{
			& iscsicli qaddtargetportal $targetPortalAddress $username $password;
		}
		else
		{
			& iscsicli qaddtargetportal $targetPortalAddress;
		}
	}
	
}

#iscsicli RemoveTargetPortal <TargetPortalAddress> <TargetPortalSocket> [HBA Name] [Port Number]
#
function Remove-TargetPortal
{
<#
This command will remove a target portal from the list of persisted target  portals. The iSCSI initiator service will 

perform a SendTargets operation to each target portal in the list whenever the service starts and whenever a full refresh 

of the target list is requested. Note that the command does not purge the targets discovered via this target portal from 

the list of targets maintained by the service.
#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[Alias('Name')]
		[string]
		# the IP or DNS address of the target portal.
		$targetPortalAddress,
		
		[Parameter()]
		[Alias('Port')]
		[int]
		#the TCP port number of the target portal. Typically this is 3260, which is the well-known port number defined for use by iSCSI.
		$TargetPortalSocket = 3260,

		[Parameter()]
		[string]
		#the name of the initiator via which the SendTargets operation is performed. If not specified then the initiator used is selected by the iSCSI initiator service.
		$InitiatorName = '', 

		[Parameter()]
		[string]
		#is the physical port number on the initiator via which the SendTargets operation is performed. If not specified then the kernel mode initiator driver chooses the initiator port used.
		$InitiatorPort = ''
	)
	
	process
	{
		& iscsicli removetargetportal $targetPortalAddress $TargetPortalSocket $InitiatorName $InitiatorPort 
	}
}

#iscsicli RefreshTargetPortal <TargetPortalAddress> <TargetPortalSocket> [HBA Name] [Port Number]
#
function Update-TargetPortal
{
<#
This command will perform a SendTargets operation to the target portal and include the discovered targets into the list of 

targets maintained by the service. It does not add the target portal to the persistent list.
#>

	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)]
		[Alias("Address")]
		[string]
		# the IP or DNS address of the target portal.
		$targetPortalAddress,

		[Parameter()]
		[Alias("Port")]
		[int]
		#the TCP port number of the target portal. Typically this is 3260, which is the well-known port number defined for use by iSCSI.
		$TargetPortalSocket = 3260,

		[Parameter()]
		[string]
		#the name of the initiator via which the SendTargets operation is performed. If not specified then the initiator used is selected by the iSCSI initiator service.
		$InitiatorName, 

		[Parameter()]
		[int]
		#is the physical port number on the initiator via which the SendTargets operation is performed. If not specified then the kernel mode initiator driver chooses the initiator port used.
		$InitiatorPort		
	)
	
	process
	{
		& iscsicli refreshtargetportal $targetPortalAddress $TargetPortalSocket $InitiatorName $InitiatorPort
	}
}

#iscsicli ListTargets [ForceUpdate]
#
#iscsicli ListPersistentTargets
#
function Get-Target
{
<#
	This command will display the list of persistent targets configured for all initiators.
#>
	[CmdletBinding(DefaultParameterSetName='Local')]
	param(
		[Parameter( ParameterSetName='Persistent' )]
		[switch]
		# specify to get persistent targets
		$persistent, 
		[Parameter( ParameterSetName='Local' )]
		[switch]
		# specify to force refresh of target list during retrieval
		$force
	)
	
	process
	{
		if( $persistent )
		{
			$data = & iscsicli ListPersistentTargets | Out-String;
			
			$data | Write-Verbose;
			$data -replace "[`r`n]+","=" -split "==" | where { $_ -match ':\s+' } | foreach {			
				$_ | convertFrom-iSCSIOutput
#				Write-Verbose "section $_";
#				$a = @{};
#				$_ -split '='  | Select-String '^\s+[\S\s]+:\s+' | foreach{ 
#						Write-Verbose "item entry $_";
#						$k,$v = $_ -split ':',2
#						$a[$k.trim(' ')] = $v.trim(' ');
#						
#						#todo - massage to match remove-target inputs
#					}		
#				new-object psobject -Property $a;
			}
		}
		else
		{
			if( $force )
			{
				$data = & iscsicli ListTargets T
			}
			else
			{
				$data = & iscsicli ListTargets
			}
			
			$data | Select-String '^\s+\S+:\S+$' | foreach{ $_ -replace '^\s+','' -replace '\s+$','' };		
		}		
	}

}

#iscsicli ListTargetPortals
#
function Get-TargetPortal
{
	[CmdletBinding()]
	param()
	process
	{
		$data = & iscsicli ListTargetPortals | Out-String;
		$data | Write-Verbose;
		$data -replace "[`r`n]+","=" -split "==" | where { $_ -match ':\s+' } | foreach {			
			$_ | convertFrom-iSCSIOutput
#			Write-Debug "section $_";
#			$a = @{};
#			$_ -split '='  | Select-String '^\s+[\S\s]+:\s+' | foreach{ 
#					Write-Debug "item entry $_";
#					$k,$v = $_ -split ':',2
#					$a[$k.trim(' ')] = $v.trim(' ');
#				}		
#			new-object psobject -Property $a;
		}
	}	
}

#iscsicli TargetInfo <TargetName> [Discovery Mechanism]
#
function Get-TargetInfo
{
<#
This command will return information about the target specified by TargetName. The iSCSI initiator service maintains a 

separate set of information about every target organized by each mechanism by which it was discovered. This means that 

each instance of a target can have different information such as target portal groups. Discovery Mechanism is an optional 

parameter and if not specified then only the list of discovery mechanisms for the target are displayed. If Discovery 

Mechanism is specified then information about the target instance discovered by that mechanism is displayed.
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[string]
		$targetName, 
		[Parameter()]
		[string]
		$discoveryMechanism 
	)
	process
	{
	}
}

#iscsicli LoginTarget <TargetName> <ReportToPNP>
#                     <TargetPortalAddress> <TargetPortalSocket>
#                     <InitiatorInstance> <Port number> <Security Flags>
#                    <Login Flags> <Header Digest> <Data Digest> 
#                    <Max Connections> <DefaultTime2Wait>
#                    <DefaultTime2Retain> <Username> <Password> <AuthType> <Key>
#                    <Mapping Count> <Target Lun> <OS Bus> <Os Target> 
#                    <OS Lun> ...
#
#iscsicli PersistentLoginTarget <TargetName> <ReportToPNP>
#                     <TargetPortalAddress> <TargetPortalSocket>
#                    <InitiatorInstance> <Port number> <Security Flags>
#                    <Login Flags> <Header Digest> <Data Digest> 
#                    <Max Connections> <DefaultTime2Wait>
#                    <DefaultTime2Retain> <Username> <Password> <AuthType> <Key>
#                    <Mapping Count> <Target Lun> <OS Bus> <Os Target> 
#                    <OS Lun> ...
#
#iscsicli QLoginTarget <TargetName>  [CHAP Username] [CHAP Password]
#
function Connect-Target
{
<#
This command will login to a target 
#>
	
	#iscsicli persistentlogintarget $t T * * * * * * * * * * * [* * *] * 0

	[CmdletBinding( SupportsShouldProcess=$true )]
	param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[Alias("Name")]
		[string]
		# the name of the target
		$targetName,	

		[Parameter()]
		[string]
		# Username is the string that should be used as the CHAP username when logging into the target. By specifying * for this parameter, the iSCSI initiator service will use the initiator node name as the CHAP username.
		$username,

		[Parameter()]
		[string]
		# Password is the string that should be used as the target�s CHAP secret when logging into the target. The initiator will use this secret to compute a hash value based on the challenge sent by the target. 
		$password,
		
		[Parameter()]
		[switch]
		# specify to persist the login information upon reboot
		$persist
	)
	process
	{	
		if( $username )
		{
			$data = & iscsicli qlogintarget $targetName $username $password
			Write-Verbose "Raw iSCSIcli output: $data";
		}
		else
		{
			$data = & iscsicli qlogintarget $targetName
			Write-Verbose "Raw iSCSIcli output: $data";
			$username = '*';
			$password = '*';

		}

		Write-Verbose "Raw iSCSIcli output: $data";
		
		if( $data -match 'already.+logged' )
		{
			$s = get-session | where { $_.targetname -eq $targetName };
			New-Object psobject -Property @{ SessionId=$s.SessionId; ConnectionId=$s.Connection.ConnectionID };
		}
		else
		{
			#		Session Id is 0xfffffa800f7900a8-0x4000013700000015
			#		Connection Id is 0xfffffa800f7900a8-0x23
		
		
		( $data | Out-String ) -replace '0x','' -replace "[`r`n]+",'=' | convertFrom-iSCSIOutput -field ' is ';
		}

		if( $persist )
		{
			& iscsicli persistentlogintarget $targetName T * * * * * * * * * * * $username $password * * 0 | Out-Null
		}
	}
}

#iscsicli LogoutTarget <SessionId>
#
function Disconnect-Session
{
<#
This command will attempt to logout of a target which was logged in via the session specified by SessionId. The iSCSI 

initiator service will not logout of a session if any devices exposed by it are currently in use.  If the command fails 

then consult the system eventlog for additional information about the component that is using the device.
#>
	[CmdletBinding( SupportsShouldProcess=$true, ConfirmImpact='high' )]
	param(
		[Parameter( Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true )]
		[string]
		$sessionId,
		
		[Parameter()]
		[switch]
		# specify to bypass standard PowerShell confirmation processes
		$force
	)
	process
	{
		if( -not( $force -or $pscmdlet.shouldProcess( $sessionId, "Disconnect Session" ) ) )
		{
			return;
		}
		
		$data = & iscsicli logouttarget $sessionId | Out-String;				
		if( $data -notmatch 'success' )
		{
			throw $data;
		}
	}
	
}


#iscsicli ListInitiators
#
function Get-Initiators
{
<#
This command will display the list of initiator instance names that are running and operating with the iSCSI initiator 

service.
#>
	[CmdletBinding()]
	param()
	process
	{
		& iscsicli listinitiators
	}
}

#iscsicli SessionList <Show Session Info>
#
function Get-Session
{
<#
This command displays the list of active sessions for all initiators. Note that a session that has no connections is not 

connected to the target and is in a retry state.

Microsoft iSCSI Initiator Version 6.1 Build 7601

Total of 2 sessions

Session Id             : fffffa800f7900a8-400001370000000d
Initiator Node Name    : iqn.1991-05.com.microsoft:archimedes
Target Node Name       : (null)
Target Name            : iqn.2008-08.com.starwindsoftware:127.0.0.1-target1
ISID                   : 40 00 01 37 00 00
TSID                   : 27 00
Number Connections     : 1

    Connections:

        Connection Id     : fffffa800f7900a8-1b
        Initiator Portal  : 0.0.0.0/58847
        Target Portal     : 192.168.1.108/3260
        CID               : 01 00

    Devices:
        Device Type            : Disk
        Device Number          : 1
        Storage Device Type    : 7
        Partition Number       : 0
        Friendly Name          : ROCKET RAM DISK 1024 M SCSI Disk Device
        Device Description     : Disk drive
        Reported Mappings      : Port 1, Bus 0, Target Id 0, LUN 0
        Location               : Bus Number 0, Target Id 0, LUN 0
        Initiator Name         : ROOT\ISCSIPRT\0000_0
        Target Name            : iqn.2008-08.com.starwindsoftware:127.0.0.1-target1
        Device Interface Name  : \\?\scsi#disk&ven_rocket&prod_ram_disk_1024_m#1&1c121344&0&000000#{53f56307-b6bf-11d0-94f2-00a0c91efb8b}
        Legacy Device Name     : \\.\PhysicalDrive1
        Device Instance        : 0x82c
        Volume Path Names      :
                                 E:\

Session Id             : fffffa800f7900a8-400001370000000f
Initiator Node Name    : iqn.1991-05.com.microsoft:archimedes
Target Node Name       : (null)
Target Name            : iqn.2008-08.com.starwindsoftware:127.0.0.1-scratch
ISID                   : 40 00 01 37 00 00
TSID                   : 2b 00
Number Connections     : 1

    Connections:

        Connection Id     : fffffa800f7900a8-1d
        Initiator Portal  : 0.0.0.0/59359
        Target Portal     : 192.168.1.106/3260
        CID               : 01 00

    Devices:
        Device Type            : Disk
        Device Number          : 2
        Storage Device Type    : 7
        Partition Number       : 0
        Friendly Name          : ROCKET RAM DISK 256 MB SCSI Disk Device
        Device Description     : Disk drive
        Reported Mappings      : Port 1, Bus 0, Target Id 1, LUN 0
        Location               : Bus Number 0, Target Id 1, LUN 0
        Initiator Name         : ROOT\ISCSIPRT\0000_0
        Target Name            : iqn.2008-08.com.starwindsoftware:127.0.0.1-scratch
        Device Interface Name  : \\?\scsi#disk&ven_rocket&prod_ram_disk_256_mb#1&1c121344&0&000100#{53f56307-b6bf-11d0-94f2-00a0c91efb8b}
        Legacy Device Name     : \\.\PhysicalDrive2
        Device Instance        : 0x8ac

#>
	[CmdletBinding()]
	param(
		[Parameter( ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true )]
		[string]
		$sessionId = '.*'
	)
	process
	{
		Write-Verbose "Session ID filter: $sessionId";
		$data = ( & iscsicli sessionlist ) | out-string;
		$data = $data -replace "[`r`n]+",'='
		Write-Verbose "raw sessionlist info : $data";
		
		$sessions = $data -split "Session Id\s+:\s+";
		$sessions = $sessions | where { $_ -match "Connections:" } | foreach {
			$session, $data = ( "Session Id : " + $_ ) -split 'Connections:', 2;
			$connection, $device = $data -split "Devices:", 2;
			
			Write-Verbose "session $session";
			Write-Verbose "connection $connection";
			Write-Verbose "device $device";	
			
			$session, $connection, $device = $session, $connection, $device | convertFrom-iSCSIOutput;
			$session | Add-Member -PassThru -MemberType NoteProperty -Name Connection -Value $connection |
					Add-Member -MemberType NoteProperty -Name Device -Value $device;
			$session;
		}
		
		if( -not $sessions )
		{
			Write-Verbose "no sessions found"
			return;
		}
		
		$sessions | write-verbose;		
		$sessions | where { write-verbose "filtering $($_.SessionId) by $sessionId"; $_.SessionId -match 

$sessionId }
	}
}

function convertFrom-iSCSIOutput
{
	[CmdletBinding()]
	param(
		[Parameter(ValueFromPipeline=$true)]
		[string]
		$data,
		
		[Parameter()]
		[string]
		$itemDelimiter = '=',
		
		[Parameter()]
		[string]
		$fieldSeparator = ':'
	)
	
	process
	{
		Write-Debug "convertFrom-iSCSIOutput ..."
		Write-Debug "  Data: $data";
		Write-Debug "  Item Delimiter: $itemdelimiter";
		Write-Debug "  Field Separator: $fieldSeparator";
		$a = @{};
		
		$data -split $itemDelimiter | where { $_ -match "$fieldSeparator\s*" } | foreach {			
					
			function add-ToA( $k, $v )
			{
				$k = $k -replace ' ','';
				Write-Debug "item key $k; value $v";
			
				$a[$k] = $v;
			}

			Write-Debug "item entry $_";
			
			$k,$v = $_ -split "\s*$fieldSeparator\s*",2;
			if( $k -match ' and ' )
			{
				$k1, $k2 = $k -split ' and ';
				$v1, $v2 = $v -split '\s+',2;
				add-ToA $k1 $v1	
				add-ToA $k2 $v2
			}
			else
			{
				add-ToA $k $v
			}
		}		
		new-object psobject -Property $a;		
	}
}

###########################################################
## initialization

Export-ModuleMember -Function '*';