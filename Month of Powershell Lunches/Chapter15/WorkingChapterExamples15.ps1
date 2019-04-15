##Working Examples for chapter 15 ##
Start-Job -ScriptBlock {dir}
Start-Job -ScriptBlock {Get-EventLog Security}
Get-Job -Name Job1
Invoke-Command -ComputerName {get-process } -ComputerName (get-content .\Allservers.txt) -AsJob -JobName MyRemoteJob
Get-Job -Id 1 |Format-List *
Receive-Job -Id 1
Start-Job -ScriptBlock {dir C:\}
Receive-Job -Id 3 -Keep
Get-Job | where { -not $_.HasMoreData}|Remove-Job
Register-ScheduledJob -Name DailyProcList -ScriptBlock {Get-Process} -Trigger (New-JobTrigger -Daily -At 2am) -ScheduledJobOption  (New-ScheduledJobOption -WakeToRun -RunElevated)

