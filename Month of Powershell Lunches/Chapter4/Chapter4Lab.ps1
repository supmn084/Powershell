Get-Process
Get-EventLog -LogName Application -Newest 100
Get-Command -CommandType Cmdlet
New-Alias -Name Np -Value Notepad.exe
Get-Service -Name M*
Show-NetFirewallRule |select name,enabled|OGV
Show-NetFirewallRule | where {$_.enabled -eq 'true' -AND $_.direction -eq 'inbound'}| select displayname