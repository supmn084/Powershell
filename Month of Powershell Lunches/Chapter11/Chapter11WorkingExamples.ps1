Get-Service -Name e*,*s*

Get-ADComputer -Filter "Name -Like '*DC'"
5 -eq 5
5 -eq 4
5 -ne 2

$_.Responding -eq $false


#Get service where status is running
Get-Service |Where-Object -FilterScript { $_.status -eq 'Running'}
#Short Version of Command Above
Get-Service |where status -eq 'Running'
#Get Version where status is running and the startup type is manual
Get-Service |Where-Object {$_.status -eq 'running' -and $_.StartType -eq 'Manual'}
#Get Top 10 thats not powershell sort by process
Get-Process |Where-Object -FilterScript { $_.Name -notlike 'Powershell*'}|sort VM -Descending |select -First 10|Measure-Object -Property VM -Sum
