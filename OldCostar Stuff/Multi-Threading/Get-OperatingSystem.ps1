# Get-OperatingSystem.ps1 ###
Param($ComputerName = "LocalHost")
$x = Get-WmiObject -ComputerName $ComputerName -Class Win32_OperatingSystem 
write-output "$ComputerName|$($x.SerialNumber)"