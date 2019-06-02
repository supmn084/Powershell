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
[cmdletbinding()]
param (
    [Parameter (Mandatory = $True, HelpMessage = "Enter a computer to query")]
    [Alias('hostname')]
    [string]$computername ,
    [ValidateSet (2, 3)]
    [int]$drivetype = 3
)
Write-Verbose "connecting to $computername"
Write-Verbose "Looking for drive type $drivetype"
Get-WmiObject -Class Win32_logicalDisk -computername $computername `
    -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Select-Object -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }