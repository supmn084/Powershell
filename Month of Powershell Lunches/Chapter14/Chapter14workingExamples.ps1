#Stuff from the examples while working through chapter 14
Get-CimInstance -Namespace root\securitycenter2 -ClassName AntiSpywareProduct
#Fun WMI find with past things
Get-WmiObject win32_service | where {$_.state -eq 'running'}
#Get contents of core OS and Hardware stuff
Get-WmiObject -Namespace root\CIMv2 -List |where name -Like '*dis*'