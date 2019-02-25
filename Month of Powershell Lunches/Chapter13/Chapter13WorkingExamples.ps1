##Stuff to try out while working through Chapter 13
## Need to set up my powershellvm as a trusted host before I can remote into it with PS (not domain joined)
Set-Item WSMan:\localhost\Client\TrustedHosts -Value 'PowershellVM' -Concatenate
##Allowed auth but need to desiginate my local administrator account for use since I don't have my chris account set up there
$cred = Get-Credential
# put in the admin password for the VM above then you can pssession 
Enter-PSSession -ComputerName Powershellvm -Credential $cred
#Success! Need to run this as admin to add it and run it every time
#enable ps remote stuff on the powershellvm
Set-WSManQuickConfig
## Test ICM
Invoke-Command -ComputerName PowershellVM -Command {get-eventlog Security -Newest 200|where {$_.EventID -eq 1212}}
#Multiple Computers from a text file
Invoke-Command -ComputerName {dir} -ComputerName (Get-Content webservers.txt)
#try it with AD parameters
Invoke-Command -Command   {dir} -ComputerName (Get-ADComputer -Filter * -SearchBase "Ou=sales,dc=company,dc=pri"|Select-Object -Expand Name)
#Running stuff on remote computers
Invoke-Command -ComputerName PowershellVM -Command {Get-Process -Name Notepad|Stop-Process} -Credential $cred
#Get running process stuff difference local vs remote
Invoke-Command -ScriptBlock {Get-Service|Get-Member} -ComputerName PowerShellVM  -Credential $cred


