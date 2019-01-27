Param  (
	$MaxThreads = 20,
    $SleepTimer = 500,
    $MaxWaitAtEnd = 600,
    $OutputType = "Gridview"
	)

Import-Module \\dcfile1\systems\scripts\PowerShell\get-ping.psm1 -Force
$ScriptFile = "\\dcfile1\systems\scripts\PowerShell\Multi-Threading\Start-Job-ScriptFile.ps1"

$Computers = get-qadcomputer  -Service 'us.costar.local' -Searchroot 'us.costar.local/_Servers' -IncludedProperties Name,LastLogonTimeStamp | ? {$_.LastLogonTimeStamp -gt (Get-Date).adddays(-60) }
$Computers += get-qadcomputer -Service 'usweb.costar.local' -Searchroot 'usweb.costar.local/_Servers' -IncludedProperties Name,LastLogonTimeStamp | ? {$_.LastLogonTimeStamp -gt (Get-Date).adddays(-60) }

$computerTmp = @()
foreach ($Computer in $Computers)	{
	$computerTmp += $Computer.name
}
$Computers = $computerTmp	 # A list with only computernames




# "Killing existing jobs . . ."
Get-Job | Remove-Job -Force

$i = 0

ForEach ($Computer in $Computers){
    While ($(Get-Job -state running).count -ge $MaxThreads){
        Write-Progress  -Activity "Creating Server List" -Status "Waiting for threads to close" -CurrentOperation "$i threads created - $($(Get-Job -state running).count) threads open" -PercentComplete ($i / $Computers.count * 100)
        Start-Sleep -Milliseconds $SleepTimer
    }

    #"Starting job - $Computer"
		if ( (get-ping -server $computer).result -eq 'PASS')	{

	   $i++
	    Start-Job -FilePath $ScriptFile -ArgumentList $Computer -Name $Computer | Out-Null
	    Write-Progress  -Activity "Creating Server List" -Status "Starting Threads" -CurrentOperation "$i threads created - $($(Get-Job -state running).count) threads open" -PercentComplete ($i / $Computers.count * 100)
	}
}

$Complete = Get-date

#
# Checking status of already submitted jobs
#
While ( ($(Get-Job -State Running).count -gt 0) -or ($(Get-Job -State Running).HasMoreData -eq $True) ) {
    $ComputersStillRunning = ""
    ForEach ($System  in $(Get-Job -state running)){$ComputersStillRunning += ", $($System.name)"}
    $ComputersStillRunning = $ComputersStillRunning.Substring(2)
    Write-Progress  -Activity "Creating Server List" -Status "$($(Get-Job -State Running).count) threads remaining" -CurrentOperation "$ComputersStillRunning" -PercentComplete ($(Get-Job -State Completed).count / $(Get-Job).count * 100)
    If ($(New-TimeSpan $Complete $(Get-Date)).totalseconds -ge $MaxWaitAtEnd){"Killing all jobs still running . . .";Get-Job -State Running | Remove-Job -Force}
    Start-Sleep -Milliseconds $SleepTimer
}

#
# "Reading all jobs"
#
#If ($OutputType -eq "Text"){
#    ForEach($Job in Get-Job){
#        "$($Job.Name)"
#        "****************************************"
#        Receive-Job $Job
#        " "
#    }
# sleep 5
If($OutputType -eq "GridView"){
    Get-Job | Receive-Job -Keep | Select-Object * -ExcludeProperty RunspaceId | out-gridview  
}