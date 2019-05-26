#Chapter 18 Working Examples
$Cred = Get-Credential
$var = "PowerShellVM"
$othervar = 5
#I don't know what they wnated to accomplish here
Invoke-Command -ComputerName $var -Credential $Cred -Command {Get-Member}
# Get server info
Invoke-Command -ComputerName $var -Credential $Cred -Command {Get-WmiObject win32_computersystem}
# array as variables  
$computers = 'Server1','Server2','Powershellvm'
# Neat way to get variables from an array as a variable
$computers[0]
#Get a count of the variables in the array
$computers.Count
#Get the length
$computers.Length
#To Upper
$computername.toupper
#Get stuff from the var
$computers|Select-Object Length
#Get other stuff from a var
$services = Get-Service
$services.Name
#the above is a shorter way than these commands
Get-Service |ForEach-Object {Write-Output $_.Name}
Get-Service|Select-Object -ExpandProperty Name
#Doing it through a var to disable start mode
$objects = Get-WmiObject -Class Win32_service -Filter "name ='BITS'"
$objects.ChangeStartMode('Disabled')
# New way to get services
$services = Get-Service
$firstname = "$Services[0].name"

