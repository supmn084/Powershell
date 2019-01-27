$metrics = "disk.numberwrite.summation","disk.numberread.summation"
$start = (Get-Date).AddMinutes(-1440)

$vms = Get-VM | where {$_.PowerState -eq "PoweredOn"}

# For single VM, un-comment below and comment above line.
#$vms = Get-VM | where {$_.Name -eq "dcsqlprd208"}

$stats = Get-Stat -Realtime -Stat $metrics -Entity $vms -Start $start
$lunTab = @{}
foreach($ds in (Get-Datastore -VM $vms | where {$_.Type -eq "VMFS"})){
	$ds.ExtensionData.Info.Vmfs.Extent | %{
		$lunTab[$_.DiskName] = $ds.Name
	}
}

$report = $stats | Group-Object -Property {$_.Entity.Name},Instance | %{
	New-Object PSObject -Property @{
		VM = $_.Values[0]
 		Disk = $_.Values[1]
		IOPSWrites = ($_.Group | Group-Object -Property Timestamp | %{$_.Group[0].Value + 0} | Measure-Object -Sum).Sum
		IOPSTotal = ($_.Group | Group-Object -Property Timestamp | %{$_.Group[0].Value + $_.Group[1].Value} | Measure-Object -Sum).Sum
		Datastore = $lunTab[$_.Values[1]]
		IOPSReads = ($_.Group | Group-Object -Property Timestamp | %{0 + $_.Group[1].Value} | Measure-Object -Sum).Sum
		IOPSAvg = ($_.Group | Group-Object -Property Timestamp | %{$_.Group[0].Value + $_.Group[1].Value} | Measure-Object -Average).Average / $interval
			
	}
}
$report | Export-Csv "C:\Counters\Disk\Real Data\IOPS_Counters_Last_1440.csv"
