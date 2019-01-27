cls



function Get-VMInfo {
	$allVMInfo = @()
	
	Get-VM | % { 
		$obj = "" | Select-Object Name,MemoryMB,PowerState,ResourcePool,VMHost
		$obj.Name = $_.Name
		$obj.MemoryMB = $_.MemoryMB
		$obj.PowerState = $_.PowerState
		$obj.ResourcePool = $_.ResourcePool
		
		$allVMInfo += $obj
	}
	$allVMInfo
}


$allVMInfo = get-vminfo
$allVMInfo |ft








