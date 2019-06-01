#Scripting Example query gets the device id, free space, total size in gb, then total percentage free local host will be default unless the user specifies otherwise when runniing
<#
.SYNOPSIS
Get-DiskInventory retrieves the logical disk information from one or more computers
.DESCRIPTION
Get-DiskInventory uses WMI to retrieve the logical disk instance from one or more computers. It displays each disk's drive letter, free space, total size, and percentage of free space
.PARAMETER computername
The computer name, or names to query, the default is localhost if nothing is input
.PARAMETER drivetype
The drive type to query. 3 is a fixed disk which is default.
.EXAMPLE
Get-DiskInventory -computername TEST -drivetype 3
#>
param (
    $computername = 'localhost' ,
    $drivetype = 3
)
Get-WmiObject -Class Win32_logicalDisk -computername $computername `
    -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Format-Table -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }
