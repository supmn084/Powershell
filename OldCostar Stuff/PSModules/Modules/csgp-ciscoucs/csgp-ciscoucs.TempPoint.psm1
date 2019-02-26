
				
#REQUIRES -Version 2.0


#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function Get-ComputeSystemMapping
{
  <#
  .SYNOPSIS
  Describe the function here
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computername
  The computer name to query. Just one.
  .PARAMETER logname
  The name of a file to write failed computer names to. Defaults to errors.txt.
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Cisco.UcsCentral.UcsCentralHandle]$ucsCentral
		
	)
	
	begin
	{
		
	}
	
	process
	{
		$ComputeSystemHash = @{ }
		# loop through each UCS cluster and build a ID  =  { Datacenter, ClusterName } mapping
		$computeSystems = Get-UcsCentralComputeSystem -UcsCentral $ucscentral
		
		foreach ($computeSystem in $computeSystems)
		{
			
			$ComputeSystemPhysicalDatacenter = $computeSystem.site
			Write-Verbose "-- $ComputeSystemPhysicalDatacenter"
			
			[int]$ComputesystemId = $computeSystem.Id
			
			$computesystemName = $computeSystem.name
			
			$tmpHash = @{ }
			$tmpHash.Add("Datacenter", $ComputeSystemPhysicalDatacenter)
			$tmpHash.Add("ClusterName", $computesystemName)
			
			
			$ComputeSystemHash.Add($ComputesystemId, $tmpHash)
			
		}
		
		return $ComputeSystemHash
		
	}
	
	End
	{
		
	}
}


<#
.SYNOPSIS
Maps the Dn of a blade to a ucs chassis name and datacenter name

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
connect-ucscentral -name server1 -cred $cred
get-BladeComputeSystemMapping -blade $blade -ucscentral $ucscentral

.EXAMPLE
connect-ucscentral -name server1 -cred $cred
$blade | get-BladeComputeSystemMapping -ucscentral $ucscentral

#>

function get-BladeComputeSystemMapping {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.ComputeBlade]$blade,
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.UcsCentralHandle]$ucscentral
	
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		
		$blade.dn -match '(compute\/sys-)(?<computesystem>\d+)(.*)' | Out-Null
		[int]$computeSystemId = $matches.computesystem
		Write-Verbose "ComputeSystemId: $computeSystemId"
		$ucscSystemMapping = $ucsCentral | Get-ComputeSystemMapping
		$clustername = $ucscSystemMapping.item($computeSystemId).clustername
		$datacenter = $ucscSystemMapping.item($computeSystemId).datacenter
		
		
		$obj = "" | Select-Object BladeSerial, ClusterName, Datacenter, BladeModel, BladeChasissId, BladeSlotId, Ram, Cores, Association, Dn, AssignedToDn
		
		$obj.bladeserial = $blade.serial
		$obj.blademodel = $blade.model
		$obj.BladeChasissId = $blade.chassisid
		$obj.bladeslotid = $blade.slotid
		$obj.clustername = $clustername
		$obj.datacenter = $datacenter
		$obj.ram = $blade.TotalMemory
		$obj.cores = $blade.numofcores
		$obj.Association = $blade.Association
		$obj.Dn = $blade.dn
		$obj.AssignedToDn = $blade.AssignedToDn
		
		
		Write-Output $obj
		
		
	}
	END
	{

	}	

}


<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function ABC {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$CHANGEME
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		# This allows you to use -WhatIf
		If ($PSCmdlet.ShouldProcess("Adding +1 to: $thatVar")) { 
			Write-Output $($thatVar + 1)
		}
	}
	END
	{

	}	

}