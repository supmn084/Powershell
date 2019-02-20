#Use net adapter to filter by virtual propery equal false
Import-Module netadapter
Get-NetAdapter -Physical
#Import NSClient Module, Get-DnsClientcache lists of records
Import-Module DnsClient
Get-DnsClientCache -Type AAAA,A
#Display exe files under C:\Windows\System32 larger than 5mb
dir C:\windows\system32 |where {$_.length -gt 5MB}
#Get Hotfixes that are security updates
Get-HotFix -Description 'Security Update'
#Display list of hotfixes that were installed by admin
Get-HotFix -Description Update |Where-Object {$_.Installedby -match "Administrator"}
Get-HotFix -Description Update |Where-Object {$_.Installedby -ne "Administrator"} ##Not Equal Test
##Display processes running with cornhost or name svhost
Get-Process -Name svchost,conhost

