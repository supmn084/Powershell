<#
.SYNOPSIS
Gets the drives on percentage of free space
.DESCRIPTION
This command will get all the local drives that have less free space than the percentage defined
.PARAMETER Computername
The computer or computer(s) you wish to run this on
.PARAMETER MinimumpercentFree
the minimum percent of free disk space. this is the threshold the default value is 10, you should enter a value from 1 to 100
.EXAMPLE
get-diskfreespace -minimum 20
#>
Param (
    $computername = 'localhost',
    $MinimumPercentFree = 10
)
#convert the minimum percent free
$minpercent = $MinimumPercentFree / 100

Get-WmiObject -Class Win32_logicaldisk -ComputerName $computername -Filter "drivetype=3" |
Where-Object { $_.Freespace / $_.size -lt $minpercent } |
Select-Object -Property DeviceID, FreeSpace, size


