##
Get-Random
Get-Date
system.datetime
get-date |select dayofweek
Get-HotFix
Get-HotFix |sort installedon |select installedon,installedby,hotfixid
Get-HotFix |sort installedon |select installedon,installedby,hotfixid |ConvertTo-Html -Title "Hotfix Report"|Out-File HotFixReport.htm
Get-eventlog -LogName System -Newest 50 |sort timegenerated,index|select index,timegenerated,source |outfile elogs.txt