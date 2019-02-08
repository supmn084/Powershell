Get-Process -ComputerName (Import-Csv -Path 'C:\dev\Powershell\Month of Powershell Lunches\chapter9\computers.csv'|select -Property hostname)


Import-Csv -Path 'C:\dev\Powershell\Month of Powershell Lunches\chapter9\computers.csv'|select -expand hostname |Get-Member
