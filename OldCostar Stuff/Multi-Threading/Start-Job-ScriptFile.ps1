Param($ComputerName = "LocalHost")
# Import-Module \\dcfile1\systems\scripts\PowerShell\get-ping.psm1 -Force
Import-Module \\dcfile1\systems\scripts\ComputerManagement\get-serviceState.psm1

if ($ComputerName -eq 'dcsox1') {  
} else {
	$ComputerName | get-serviceState -service 'BESClient'
}
