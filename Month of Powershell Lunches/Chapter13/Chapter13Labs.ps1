#stuff for chapter 13 labs worked through
#1 Open notepad in a remote computer
Enter-PSSession -ComputerName Powershellvm -Credential $Cred
#2 Get services not running
Invoke-Command  -Command {get-service | where {$_.status -eq "stopped"}} -ComputerName Powershellvm -Credential $Cred
#3 Get top 10 processes using memory
Invoke-Command -Command {Get-Process | sort VM -Descending |select-first 10} -ComputerName PowerShellVM -Credential $Cred
#4 Create text file with computer names. Retreive application entries from those
Invoke-Command -Command {Get-EventLog Application -Newest 100} -ComputerName (Get-Content -Path 'C:\dev\powershell\Month of Powershell Lunches\chapter13\Servers.txt') -Credential $Cred
#5 get remote computers to display productname, edition, current version
Invoke-Command -ScriptBlock {Get-ItemProperty 'HKLM:\software\microsoft\windows NT\CurrentVersion\'|select ProductName,EditionID,CurrentVersion} -ComputerName PowershellVM -Credential $Cred




