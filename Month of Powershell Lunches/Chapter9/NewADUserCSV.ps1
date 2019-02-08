##Get's list of users from CSV and title columns, generates the output to a digestable format for New-ADUser
Import-Csv -Path 'C:\dev\PowerShell\Month of Powershell Lunches\chapter9\newusers.csv'|
Select-Object -Property *,
@{name ='SamaccountName';expression = {$_.login}},
@{label='Name';expression = {$_.login}},
@{n ='Department';expression = {$_.Dept}}|New-ADUser

##Run a command on multuple computers
Get-WmiObject -Class Win32_BIOS -ComputerName ( Get-Content -Path 'C:\dev\PowerShell\Month of Powershell Lunches\chapter9\servers.txt')

#Get Computers in OU
Get-ADComputer -Filter * -SearchBase "OU=WHERE,OU=STUFF,OU=YOU,OU=WANT,DC=company"
