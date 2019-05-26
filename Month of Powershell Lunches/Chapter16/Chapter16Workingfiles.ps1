#Working Examples through Chapter 16
# Get service examples to set automatic
Get-Service -Name BITS,Spooler,W32Times |Set-Service -StartupType Automatic
#Multiple Computers
Get-Service -Name BITS,Spooler,w23Tiome -ComputerName Server1,Server2,Server3 |Set-Service -StartupType Automatic
#Pass output through
Get-Service -Name BITS -ComputerName Server1,Server2,Server3 |Start-Service -PassThru|Out-File NewServiceStatus.txt
# Administrator credentials for Powershell VM
$Cred = Get-Credential
#Book Example Assuming your credentials work for the computer
Get-Service -Name BITS -ComputerName PowerShellVM -credential $Cred |Start-Service -PassThru 
#Set to work in my setup using ICM
Invoke-Command -ComputerName Powershellvm -Credential $Cred -Command {Get-Service -Name BITS|Start-Service -PassThru}
# WMI Query to find network adapters
Get-WmiObject win32_networkadapterconfiguration -Filter "description like '%intel%'"
# Changing it up to get the properties to change up
Get-WmiObject win32_networkadapterconfiguration -Filter "description like '%intel%'"|Get-Member
# Getting the properties for enabledhcp
Get-WmiObject win32_networkadapterconfiguration -Filter "description like '%intel%'"|Invoke-WmiMethod -Name enabledhcp -WhatIf
#Change password parameter for the service running with bits
Get-WmiObject Win32_service -Filter "name = 'BITS'"|ForEach-Object -Process {$_.Change($null,$null,$null,$null,$null,$null,$null,$null,"P@ssw0rd")}
# Batch cmdlet
Get-Service -Name *B* |Stop-Service
# For Each Example
Get-Service -Name *B* |ForEach-Object { $_.Stop()}
# WMI Object
Get-WmiObject Win32_service -Filter "name LIKE '%B%'"|Invoke-WmiMethod -Name Stop-Service
# WMI for Each Object
Get-WmiObject Win32_service -Filter "name LIKE '%B%'" | ForEach-Object {$_.StopService()}
# Power Shell Stop Service
Stop-Service -Name *B*


