#Questions from the chapter
#1 Close all open sessions in your shell
Get-PSSession|Remove-PSSession
#2 Establish a session to a remote computer
$session = New-PSSession -ComputerName localhost
#3 use the session variable to establish a one to one remote shell session
Enter-PSSession $session
Get-Process
Exit
#4 Use variable to invoke command
Invoke-Command -ScriptBlock {Get-Service} -Session $session
#5 use pssession to get list of most recent security log entries
Invoke-Command -ScriptBlock {Get-EventLog -LogName System -Newest 20} -Session (Get-PSSession)
#6 Use invoke command to load server manager module on remote computer
Invoke-Command -ScriptBlock {Import-Module ServerManager} -Session $session
#7 import server manager modules from remote computer to computer, at prefix rem to imported ocmmand nouns
Import-PSSession -Session $session -Prefix rem -Module ServerManager
#8 run the imported get-windows feature command
get-remwindowsf
#9 close the session thats in your variable
Remove-PSSession -Session $session