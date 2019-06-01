#Scripting Example query gets the device id, free space, total size in gb, then total percentage free
Get-WmiObject -Class Win32_logicalDisk -computername localhost -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Format-Table -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }

#adding variables for the computername
$computername = 'localhost'
Get-WmiObject -Class Win32_logicalDisk -computername $computername `
    -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Format-Table -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }

#Lets make it a parameter for user input
param (
    $computername = 'localhost'
)
Get-WmiObject -Class Win32_logicalDisk -computername $computername `
    -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Format-Table -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }

#More Parameters for fun
param (
    $computername = 'localhost',
    $drivetype = 3
)
Get-WmiObject -Class Win32_logicalDisk -computername $computername `
    -Filter "drivetype=3" | 
Sort-Object -Property DeviceID |
Format-Table -Property DeviceID,
@{label = 'FreeSpace (MB)'; expression = { $_.FreeSpace / 1MB -as [int] } },
@{label = 'Size(GB)'; expression = { $_.Size / 1GB -as [int] } },
@{label = '%Free'; expression = { $_.FreeSpace / $_.Size * 100 -as [int] } }
