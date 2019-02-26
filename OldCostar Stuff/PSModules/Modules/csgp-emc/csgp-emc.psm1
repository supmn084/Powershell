#
# General purpose EMC cmdlets
#

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

<#
		.SYNOPSIS
			This function checks for the SecuredCLIXMLEncrypted.key in your user directory

		.DESRIPTION
			SecuredCLIXMLEncrypted.key indicates that you have attempted to setup
			security with naviseccli.exe using the -AddUserSecurity feature.
			
#>
function test-csgpEmcNaviUserSecurity {

[CmdletBinding(supportsshouldprocess=$true)]
	param (
	
	)

	BEGIN	{
	$homeDrive = $env:HOMEDRIVE
	$homePath = $env:HOMEPATH
	$keyFile = "$homeDrive\$homePath\SecuredCLIXMLEncrypted.key"

	}

	PROCESS	{
	
	If (! (Test-Path $keyFile) )	{
		Write-Error "We can't seem to find your Naviseccli keyfile. Default location is at $keyfile.`n`nUse naviseccli -addusersecurity -scope 2 -user $env:username`n"
	}
		
	}
	END	{

	}	

}

<#
	.SYNOPSIS
		This function prepares the System.Diagnostics.Process parameters needed to get a good 
		clean invocation of naviseccli.exe

	.DESRIPTION
		Does not attempt to parse the output
#>
function new-csgpEmcNaviCommand {
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
	
	BEGIN	{

	}
	
	PROCESS { 
	
	$ps = new-object System.Diagnostics.Process 
	$ps.StartInfo.Filename = $cmd 
	$ps.StartInfo.Arguments = " -address $spAddress $naviCmd"
	if ($echo)	{
		Write-Verbose "$($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"
	}
	$ps.StartInfo.RedirectStandardOutput = $True 
	$ps.StartInfo.UseShellExecute = $false
	$ps.StartInfo.CreateNoWindow = $true
	$ps.start() | Out-Null
	# $ps.WaitForExit()	# Thsi can cause the command to run, but hang, not producing output until the exe is killed.
	[string] $result = $ps.StandardOutput.ReadToEnd();
	$result = $result.trim()
	write-output $result
	}
	
	END {
	
	}
}

<#
.SYNOPSIS
Creates a new destination LUN using naviseccli

.DESCRIPTION

.EXAMPLE 
new-csgpEmcDestinationLun -dstPool MyDstPool -capacity 1300 -name NameofNewLun -ProvisioningType Thin -storageSystem $storSys -LunOwner $lunTable.DefaultOwner -spAddress $spAddress -tieringPolicy $tieringPolicy

#>
function new-csgpEmcDestinationLun {
[CmdletBinding()]
	param(
		# The name of the destination pool
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$dstPool,
		# Capacity in GB for the new LUN
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$Capacity,
		# The name of the new LUN
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[parameter(Mandatory=$true)]
		# Thin|nonThin
		[ValidateNotNullOrEmpty()]
		[string]$ProvisioningType,
		# $storageSystem is the friendly name of the storage system as seen in the EMC ESI application
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
			$storageSystem,
		# The DNS name of SPA or SPB: [SANNAME]-SPA or [SANNAME]-SPB
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
			$spAddress,
		# Specify which SP should own the LUN: SPA or SPB
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
			$LunOwner,
		# If you need to you can set the tiering policy: lowestAvailable|highestAvailable
		[parameter(Mandatory=$false)]
			[string]$tieringPolicy
		)
	
	[EMC.WinApps.Fx.Size]$newLunCapacity = $Capacity+"gb"	# WOW, getting this type correct was hard
	$LunOwner = ($LunOwner -split("\s"))[1]	# A or B
	$newLunName = $Name+"_TO_MIGRATE"
	[int]$capacityInt = $capacity	# integer size
	
	write-verbose "Creating LUN $newLunName in pool $dstpool, size $capacityInt"
	if ($ProvisioningType -eq 'Thick') 	{
		$lunType = 'nonThin'
	} else {
		$lunType = 'Thin'
	}
	
	# Set tiering policies
	if ($tieringPolicy -eq 'LowestAvailable') {
		$initialtier = 'lowestAvailable'
		$tieringPolicy = 'lowestAvailable'
	} else {
		# If not lowestAvailable we set to our standard of Start High then auto tier
		$initialtier = 'highestAvailable'	
		$tieringPolicy = 'autotier'
		}
	
	# Create the LUN
	new-csgpEmcNaviCommand -spaddress $spAddress -naviCmd "lun -create -type $lunType -capacity $capacityInt -sq gb -poolname `"$dstpool`" -sp $LunOwner -name $newLunName -initialtier $initialtier -tieringPolicy $tieringPolicy" -echo
	
	# List the Lun so we can get the Lun ID, we could do with POSH but we'd have to refresh the storage system first
	$naviLunList = new-csgpEmcNaviCommand -spaddress $spAddress -naviCmd "lun -list -name $newLunName"
	$naviLunList -MATCH '(LOGICAL UNIT NUMBER\s+)(.*)' | Out-Null
	$newArrayLunId = $Matches[2].trim()	# the new LUN number
	Write-Verbose "Destination Lun Id is `"$newArrayLunId`" "
	
	Write-Output $newArrayLunId	# The new ID of the lun
	

}

<#
.SYNOPSIS
Registers a VNX block device if not already registered in EMC ESI
Version 1.00

.DESCRIPTION

.EXAMPLE


#>
function connect-csgpEmcSystem {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		# The friendly name of the VNX array, use VISAN101 but not VISAN101-SPA
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$array
			)

  BEGIN	{
	if (! (Get-Module esipstoolkit) ) {
		Write-Error "Use x64 Powershell or please load the esipstoolkit using 'import-module esipstoolkit'"
	}
  }

  PROCESS	{
	if (! (get-emcstoragesystem | ? { $_.name -eq $array} ) ) {
		Write-Host "We did not find VNX array $array on the EMC ESI installation on this administrative computer.`
			`n`nFill out the Add Storage System dialog box using the following parameters:`n`
			System Type: VNX-BLOCK`n `
			Friendly Name: $array`n `
			Username & Password: Use a local account on the VNX (not my fault)`n `
			SPA and SPB IP address: Use ARRAYNAME-SPA or ARRAYNAME-SPB" `
			-ForegroundColor DarkYellow
		$storSysCred = Get-EmcStorageSystemCredential
		$storSys = connect-emcsystem -creationblob $storSysCred
		Write-Output $storSys
	} else {
		# array already exists, get object
		$storSys = get-emcstoragesystem -ID $array
		Write-Output $storSys	
	}
	}
  END	{

	}	

}

<#
.SYNOPSIS
Will get or register a Windows host in the EMC ESI
Version 1.00

.DESCRIPTION

.EXAMPLE


#>
function connect-csgpEmcHostSystem {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		# get or register a Windows host in the EMC ESI
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
			)

  BEGIN	{
	if (! (Get-Module esipstoolkit) ) {
		Write-Error "Use x64 Powershell or load the esipstoolkit using 'import-module esipstoolkit'"
	}

  }

  PROCESS	{
	#
	# Check and add host to ESI
	#
	if (! (get-emchostsystem | ? {$_.Name -eq $computer}) ) {
		Write-Host "We did not find computer $computer in the `nEMC ESI installation on this administrative computer.`n`nFill out the Add Host dialog box.  You may use your current login credentials to register this new host." -ForegroundColor DarkYellow
		$emcHostCred = Get-EmcHostSystemCredential
		$emcHostSystem = Connect-EmcSystem -CreationBlob $emcHostCred
		Write-output $emcHostSystem
	} else {
		$emcHostSystem = get-emchostsystem -id $computer 
		Write-output $emcHostSystem
	}

  }
  END	{

	}	

}

<#
.SYNOPSIS
Get a objects related to the local disks on a server, used to create a list of
	Windows volumes what will be created for EMC Open Migrator
Version 1.00

.DESCRIPTION
Excludes the C: drive

#>
function get-csgpHostDisksForEmcMigration {
[CmdletBinding(supportsshouldprocess=$True)]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$computer
	)
		

  BEGIN	{

	}

  PROCESS	{
	$Disks = gwmi -namespace 'root\CIMV2' -computername $computer -Class Win32_LogicalDisk | ? { ( ($_.DriveType -eq 3) -and ($_.Name -ne "C:") ) }
	foreach ($disk in $Disks)	{
		$newEmcLunSizeGb = [Math]::Round($disk.size / 1GB,0) + 1
		$obj = @()
		$obj = "" | select-object SystemName,Caption,NewEmcLunSizeGb,VolumeName
		$obj.SystemName = $disk.SystemName
		$obj.Caption = $disk.Caption
		[int]$obj.NewEmcLunSizeGb = $newEmcLunSizeGb
		$obj.VolumeName = $disk.VolumeName
		if (($obj.VolumeName).length -gt 31)	{
			Write-Error "Windows volume $($obj.VolumeName) has more than 31 characters in it's name`nWe need at least 1 spare character to differeniate this new temporary volume from the original when working with Open Migrator`nPlease shorten the original volume name in Windows and run this script again."
		}
		Write-Output $obj
	}

  }
  END	{

	}	

}

<#
.SYNOPSIS
This function performs a LUN migration (Same as Unisphere except all-in-one)

.DESCRIPTION

.EXAMPLE 
Import-Module csgp-emc -Force
$results = 37 | new-csgpEmcMigrateLun -storageSystem VISAN100 -spAddress VISAN100-SPA -dstPool 'RAIDSWAP' -RATE 'high'

.EXAMPLE 
Import-Module csgp-emc -Force
$results = 47,37 | new-csgpEmcMigrateLun -storageSystem VISAN100 -spAddress VISAN100-SPA -dstPool 'RAIDSWAP' -RATE 'high' -tieringPolicy LowestAvailable -ProvisioningType thin

.EXAMPLE 
Import-Module csgp-emc -Force
$results = 47,37 | new-csgpEmcMigrateLun -storageSystem VISAN100 -spAddress VISAN100-SPA -dstPool 'RAIDSWAP' -RATE 'high' -tieringPolicy LowestAvailable -ProvisioningType Thick


#>
function new-csgpEmcMigrateLun {
	[CmdletBinding()]
	param(
		# The friendly name of the storage system in EMC ESI (like VISAN100 or VISAN101)	
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateSet("DCSAN100", "DCSAN101", "VISAN100", "VISAN101", "VISAN102", "LASAN100")]
		[string]$storageSystem,
		# The name of the destination pool
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$dstpool, 
		# Migration rate (low, medium, high)
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$rate, 
		# The LUN number of the source LUN (like 1, 10, 11)
		[parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
		[ValidateNotNullOrEmpty()]
		[string]$LunId, 
		# The string name of the source LUN
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$LunName, 
		# The management IP address of the service processor (EX: [SANNAME]-SPA)
		#[parameter(Mandatory=$true)]
		#[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateSet("DCSAN100-SPA", "DCSAN100-SPB", "DCSAN101-SPA", "DCSAN101-SPB", "VISAN100-SPA", "VISAN100-SPB", "VISAN101-SPA", "VISAN101-SPB", "VISAN102-SPA", "VISAN102-SPB", "LASAN100-SPA", "LASAN100-SPB")]
		[string]$spAddress, 
		# The tiering policy (highestAvailable, lowestAvailable)
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$tieringPolicy,
		# Thin or Thick
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string]$ProvisioningType

		)
	
	BEGIN
	{
		$migrationTable = @() # global migration table
		
		Test-csgpEmcNaviUserSecurity
		
		# Import esipstoolkit module
		try {
			import-module 'C:\Program Files\EMC\EMC Storage Integrator\esipstoolkit'
		} catch {
			Write-Error "Ensure you are using x64 powershell, and you must install the EMC ESI with powershell CMDLETS"
		}
		
		# Get storage system info from the ESI and refresh it
		$storSys = Get-EmcStorageSystem -Id $storageSystem
		Write-Host "Updating ESI system inventory, please wait $(get-date)..." -ForegroundColor green
		$storSys | Update-EmcSystem -Silent
	}
	
	PROCESS
	{
		# Grab input of either LUN ID or LUN Name
		if ($LunId)	{
			$lun = $LunId
		} elseif ($LunName)	{
			$lun = $LunName
		} else {
			Write-Error "Missing -LunId or -LunName"
		}
		
		$lunTable = @() # itteration migration table
		
		
		# Pool Lun objects
		$poolLun = $storSys | Get-EmcLun | ? {( ($_.name -eq $lun) -or ($_.ArrayLunId -eq $lun) )}
	
		# define table
		$lunTable = "" | Select-Object LunSrcId,LunDstID,Capacity,OrigPool,PoolDst,Name,ProvisioningType,DefaultOwner,DateTime
		
		# Pool name is not in get-emclun properties so we have to try another way
		$poolIdOriginalLun = ( ($storsys | get-EMClun | ? {$_.ArrayLunID -eq $poolLun.ArrayLunId }).ArrayPoolIds )[0]	# result looks like pool:[poolId]
		$lunTable.OrigPool = ($storsys | get-emcstoragepool -id $poolIdOriginalLun).Name  # the original pool name of the LUN
		
		$lunTable.LunSrcId = $poolLun.ArrayLunId	# source LUN ID
		$lunTable.Name = $poolLun.Name	# Lun name
		$lunTable.PoolDst = $dstpool	# destination pool
		$lunTable.DateTime = $(Get-Date)
		
		# Get capacity in GB
		$capacityGb = convert-csgpEmcCapacityToGb -capacity $poolLun.Capacity	
		$lunTable.Capacity = $capacityGb
		
		if (! $ProvisioningType)	{
			# If not specified use the same type as the source LUN
			$ProvisioningType = $poolLun.ProvisioningType
		}
		
		$lunTable.ProvisioningType = $ProvisioningType	# thick or thin
		$lunTable.DefaultOwner = $poolLun.ServiceNodeIds	# output will be exactly 'SP A' or 'SP B'
		
		# Create a new destination LUN with naviseccli (new-emclun cmdlet does not suport specifying storage processor)
		#	and return the new LUN ID
		Write-Host "Creating new $ProvisioningType destinaton lun on $dstpool" -ForegroundColor Green
		
		$lunTable.LunDstID = new-csgpEmcDestinationLun -dstPool $dstpool -capacity $capacityGb -name $poolLun.Name -ProvisioningType $ProvisioningType -storageSystem $storSys -LunOwner $lunTable.DefaultOwner -spAddress $spAddress -tieringPolicy $tieringPolicy
		
		$migrationTable += $lunTable # Add to table
		
		# Run the navi command to migrate the LUN (no POSH cmdlet to do this)
		#foreach ($lun in $migrationTable)	{
		foreach ($lun in $lunTable)	{
			Write-host "Migrating lun $($lun.LunSrcId) to $($lun.LunDstID)|$ProvisioningType" -ForegroundColor Green
			new-csgpEmcNaviCommand -spAddress $spAddress -naviCmd "migrate -start -source $($lun.LunSrcId) -dest $($lun.LunDstId) -rate $rate -o" -echo
		}
	}
	
	END
	{
		Write-Output $migrationTable
	}

}

<#
	.SYNOPSIS
		This function takes the Capacity property and converts it to GB

	.DESCRIPTION
		Stupid EMC uses various units for this property based on relative size of LUN. 
		for example they use TB and GB based on LUN size.
#>
function convert-csgpEmcCapacityToGb {

	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$capacity
		)
	
	If ($capacity -match "\sGB")	{
		# need to strip " GB"
		$capacity -match '(\w+.\w+)(.*)' | out-null
		[double]$capacityGb = $Matches[1]
	}
	elseif ($capacity -match "\sTB")	{
		# need to strip " TB"
		$capacity -match '(\w+.\w+)(.*)' | out-null
		[double]$capacityTb = $matches[1]
		# need to convert to GB
		[double]$capacityGb = $capacityTb * 1KB
	}
		Write-Output $capacityGb
}

<#
.SYNOPSIS
Lists files via the naviseccli managemfiles -list command

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
get-csgpEmcManageFilesList -spaddress [sanname]-spa

#>
function get-csgpEmcLoggingFilesList {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$spAddress 
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$spLoggingFiles = naviseccli -h $spAddress managefiles -list
		$report = @()
		$cnt = 0
		foreach ($row in $spLoggingFiles)	{
			if ($cnt -eq 0)	{ $cnt++; continue } # skip header row
	
			$obj = @()
			$obj = "" | Select-Object Index,SizeKb,Modified,Filename
			$row -match '(.{6})(.{10})(.{21})(.*)' | Out-Null 
			
			$obj.Index = $matches[1]
			$obj.SizeKb = $matches[2]
			$obj.Modified = $matches[3]
			$obj.FileName = $matches[4]
			
			$report += $obj
		}
		
		Write-Output $report
	}
	END
	{

	}	
	
	
}

<#
.SYNOPSIS
Creates a new SP collect on the SP

.DESCRIPTION


.PARAMETER

.PARAMETER

.EXAMPLE
new-csgpEmcSpCollect -spaddress [sanname]-spa

#>
function new-csgpEmcSpCollect {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$spAddress 
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$spLoggingFiles = get-csgpEmcLoggingFilesList -spAddress $spAddress
		$spcollectObj = $spLoggingFiles | ? {$_.Filename -like "*runlog*" }
		if ($spcollectObj)	{
			Write-Host "WARNING: You are already running a spCollect on $spAddress. $($spcollectObj.Filename)" -ForegroundColor Yellow
		} else {
			# Run the spcollect
			$spCollectOutput = naviseccli -h $spAddress spcollect	#output is null
		}
		
	}
	END
	{

	}	
	
	
}

<#
	.SYNOPSIS
		Creates the syntax needed to create 4 fiber channel zones for UCS blades
	
	.DESCRIPTION
		On UCS & Fibre channel we will create 2 zones on switch-A and 2 zones on switch-B.  This is very error prone expecially with the zoneset activate command.  This module will print out something we can copy and paste into each switch
	
	.PARAMETER fd
		SAN switch A or B
	
	.NOTES
		Additional information about the function.

	.EXAMPLE
		PS C:\> Get-Something -ParameterA 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the Get-Something function with named parameters.

	.EXAMPLE
		PS C:\> Get-Something 'One value' 32
		'This is the output'
		This example shows how to call the Get-Something function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

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

<#
	.SYNOPSIS
		A brief description of the New-csgpFCZone function.
	
	.DESCRIPTION
		A detailed description of the New-csgpFCZone function.
	
	.PARAMETER computer
		the computer being added to the FC switch
	
	.PARAMETER fd
		The failure domain (A or B)
	
	.PARAMETER wwpn
		The unique identifier for the FC port.  Cisco calls this a pwwn on the Nexus switch
	
	.PARAMETER san
		The friendly name of the san (DCSAN100, DCSAN101, ETC)
	
	.EXAMPLE
		PS C:\> New-csgpFCZone -computer 'MyServer' -fd A -san DCSAN100 -WWPN 20:00:00:25:b5:3a:00:00
	
	.NOTES
		Additional information about the function.
#>
function New-csgpFCZone	{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateSet("DCSAN100", "DCSAN101", "DCSAN102", "VISAN100", "VISAN102", "VISAN102")]
		[string]$san,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateLength(1, 1)][ValidateSet("A", "B")]
		[string]$fd,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
		[string]$computer,
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][ValidateLength(23, 23)]
		[string]$wwpn,
		# 20:00:00:25:b5:3a:00:00
		[Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
		[switch]$forceEven,
		[Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()]
		[switch]$forceOdd
	)
	begin {
		try
		{
		}
		catch
		{
			
		}
	}
	process {
		
		try
		{
            if ($forceEven)
            {
                $isEven = $true	
            }		
            
            eslseif ($forceOdd)
            {
                $isEven = $false	
            }

            else
            {
                $isEven = Test-HostNameEven -computer $computer
            }
			
			
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
			$wwpn = $wwpn.ToLower()
			
			$cmd = @"
#
#
# Addding host to the -$hostParity- FC ports & zone on SWITCH-$($fd.toupper() )
#
#
config t
# Create new fcalias
fcalias name $($computer)_$($vhba) vsan $($vsan)
member pwwn $($wwpn)
exit
#
# Create zone for first path from $($vhba) to $($arrayPort1) (fd: $($fd))
zone name $($computer)_$($vhba)-$($san)_$($arrayPort1) vsan $vsan
# Add server first path
member fcalias $($computer)_$($vhba)
# Always use $($san)_$($arrayPort1) for first path
member fcalias $($san)_$($arrayPort1)
exit
#
# Create zone for second path from $($vhba) to $($arrayPort2) (fd: $($fd))
zone name $($computer)_$($vhba)-$($san)_$($arrayport2) vsan $($vsan)
# Add server second path
Member fcalias $($computer)_$($vhba)
# Always use $($san)_$($arrayPort2) for second path
member fcalias $($san)_$($arrayPort2)
exit
#
# Add zones to the zoneset and enable the zoneset changes
zoneset name zoneset_vsan$($vsan) vsan $vsan
#
# add both zones you created in above step
member $($computer)_$($vhba)-$($san)_$($arrayPort1)
member $($computer)_$($vhba)-$($san)_$($arrayPort2)
#
# Activate the zoneset changes
zoneset activate name zoneset_vsan$($vsan) vsan $($vsan)
exit
#
#

"@
			CLS
			Write-output "$cmd"
			
		}
		catch
		{
			Write-Error "There is an error in your 'here-string' "
		}
			
	}
	end {
		try {
		}
		catch {
		}
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
function Test-HostNameEven {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
		[string]$computer
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
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
	end {
		try {
		}
		catch {
		}
	}
}
