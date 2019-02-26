
				
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
