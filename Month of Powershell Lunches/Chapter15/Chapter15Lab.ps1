#Lab Results#
#1 Create one time background to find the powershell scripts on the C: drive
Start-Job {dir C:\ -Recurse -Filter '*.ps1'}
#2 identify all powershell scripts on some servers. How to run on remote computers in the same command above.
Invoke-Command -ScriptBlock {dir C:\ -Recurse -Filter *.ps1} -ComputerName (Get-Content computers.txt) -AsJob
#3 Create background job to get the last 25 errors in the event job. Want it to run at 6 amd every day M-F
$trigger=new-jobtrigger -at "6:00AM" -DaysOfWeek "Monday","Tuesday","Wednesday","Thursday","Friday" -Weekly
$command = {Get-EventLog -LogName System -Newest 25 -EntryType Error |Export-Clixml C:\Work\25syserr.xml}
Register-ScheduledJob -Name "Get 25 System Errors" -ScriptBlock $command -Trigger $trigger
Get-ScheduledJob|select *
#4 What command would you use to get results of a job and how do you save it?
Recieve-job  -id 1 -keep    
