
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


<#
.SYNOPSIS
Adds a new EMC LUN to a Windows host

.DESCRIPTION

.EXAMPLE
$lun = add-csgpEmcDisk -lunCapacityGb $lunCapacityGb -lunName bentest1 -emcPool $emcPool

#>
function add-csgpEmcDisk {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.Size]$lunCapacityGb,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$lunName,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.DataModel.StorageSystem.LunStoragePool]$emcPool
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		#
		# Adding disk
		#
		
		# Create LUN on storage system.
		# Note that I can't select the Tiering options or compression
		$lun = New-EmcLun -Capacity $lunCapacityGb -Name $lunName -Pool $emcPool -Thick
		
		# output the lun object, it's needed to mount and format the LUN
		Write-output $lun
		
	}
	END
	{

	}	

}


<#
.SYNOPSIS
Unmask LUN, refresh & rescan disks on host, format, online and add drive letter
Version 1.00

.DESCRIPTION

.EXAMPLE
new-csgpEmcWindowsVolume -emcHostSystem $emcHostSystem -lun $lun
Unmask LUN, refresh & rescan disks on host, format, online and add drive letter


#>
function new-csgpEmcWindowsVolume {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.Adapter.HostSystem.WindowsHostSystem.WindowsHostSystem]$emcHostSystem,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.DataModel.StorageSystem.ConcreteLun]$lun
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		# Unmask LUN to this host
		$emcLunAccess = Set-EmcLunAccess -lun $lun -HostSystem $emcHostSystem -Available
		
		# Get the host disk info from the LUN we just unmasked
		# 	We will need this object/info in order to use Set-EmcHostDiskOnlineState when tearing down a volume
		# 	May not actually need to use Set-EmcHostDiskOnlineState and can just mask the lun instead
		$emcHostDisk = Find-EmcHostDisk -HostSystem $emcHostSystem -Lun $lun
		
		# Initialize the disk with a certain partition type
		Initialize-EmcHostDisk -HostDisk $emcHostDisk  -HostSystem $emcHostSystem -PartitionStyle MBR 
		
		# Create a new NTFS volume
		$emcVol = New-EmcVolume -HostSystem $emcHostSystem -HostDisk $emcHostDisk -AllocationUnitSizeInBytes 65536 -FileSystemType NTFS -LABEL $($lun.name)
		# List available drives
		$hostDrives = Get-EmcAvailableDriveLetter -HostSystem $emcHostSystem # available drives
		$nextHostDriveLetter = ($hostDrives | ? {$_ -ne 'B' })[0]	# Skip the B drive and pick next drive letter
		
		# Mount the drive to a drive letter
		$emcVolMountPoint = Set-EmcVolumeMountPoint -HostSystem $emcHostSystem -Volume $emcVol -DriveLetter $nextHostDriveLetter

	}
	END
	{

	}	
}

#>
function new-csgpEmcWindowsMountPoint {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.Adapter.HostSystem.WindowsHostSystem.WindowsHostSystem]$emcHostSystem,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[EMC.WinApps.Fx.DataModel.StorageSystem.ConcreteLun]$lun,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$mountpath
	
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		# Unmask LUN to this host
		$emcLunAccess = Set-EmcLunAccess -lun $lun -HostSystem $emcHostSystem -Available
		
		# Get the host disk info from the LUN we just unmasked
		# 	We will need this object/info in order to use Set-EmcHostDiskOnlineState when tearing down a volume
		# 	May not actually need to use Set-EmcHostDiskOnlineState and can just mask the lun instead
		$emcHostDisk = Find-EmcHostDisk -HostSystem $emcHostSystem -Lun $lun
		
		# Initialize the disk with a certain partition type
		Initialize-EmcHostDisk -HostDisk $emcHostDisk  -HostSystem $emcHostSystem -PartitionStyle MBR 
		
		# Create a new NTFS volume
		$emcVol = New-EmcVolume -HostSystem $emcHostSystem -HostDisk $emcHostDisk -AllocationUnitSizeInBytes 65536 -FileSystemType NTFS -LABEL $($lun.name)
		
		# List available drives
		#$hostDrives = Get-EmcAvailableDriveLetter -HostSystem $emcHostSystem # available drives
		#$nextHostDriveLetter = ($hostDrives | ? {$_ -ne 'B' })[0]	# Skip the B drive and pick next drive letter
		
		# Mount the drive to a drive letter
		$emcVolMountPoint = Set-EmcVolumeMountPoint -HostSystem $emcHostSystem -Volume $emcVol -MountPath $mountpath
		

	}
	END
	{

	}	
}

<#
.SYNOPSIS
Removes a mounted disk - This module is not ready 
Version 1.00

.DESCRIPTION

.EXAMPLE

#>
function remove-csgpEmcDisk {
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
	
		return # this module is not ready yet
		
		#
		# Removing disk
		#
		# If you have just recently finished adding a drive this object will automatically be updated
		#	but if you are coming back to this system in a new PowerShell session you need to update-emcsystem on the host
		$emcHostSystem | update-emcSystem	
		
		# Will need to find a good way to figure out how to track drive letter if coming back to this script when doing a volume refresh
		$emcHostVolumeObj = $emcHostSystem | Get-EmcHostVolume | ? { $_.MountPath -eq 'G:\' }
		
		# Remove drive letter
		Remove-EmcVolumeMountPoint -Volume $emcHostVolumeObj -HostSystem $emcHostSystem
		
		# Offline disk
		# Get the host disk info from the LUN we just unmasked
		$emcHostDisk = Find-EmcHostDisk -HostSystem $emcHostSystem -Lun $lun
		
		# Set disk offline
		Set-EmcHostDiskOnlineState -HostDisk $emcHostDisk -Offline
		
		# Mask the LUN and remove from Storage Group
		Set-EmcLunAccess -lun $lun -HostSystem $emcHostSystem  -Unavailable
		
		# Delete the LUN from the storage system.
		Remove-EmcLun -Lun $lun -Confirm:$false

	}
	END
	{

	}	

}