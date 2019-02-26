
				
#REQUIRES -Version 2.0


#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

<#
.SYNOPSIS
Given a ucscentral object, will output a hash object showing the ID
of the UCSM domain as well as the datacenter name and cluster name of the UCSM instance


.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
$blade.dn -match '(compute\/sys-)(?<computesystem>\d+)(.*)' | Out-Null
[int]$computeSystemId = $matches.computesystem
$ucscSystemMapping = $ucsCentral | Get-ComputeSystemMapping
$clustername = $ucscSystemMapping.item($computeSystemId).clustername
$datacenter = $ucscSystemMapping.item($computeSystemId).datacenter

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
		
		
		$obj = "" | Select-Object BladeSerial, Hostname, Datacenter, ClusterName, BladeChasissId, BladeSlotId, BladeModel, Ram, Cores, Association, Dn, AssignedToDn
		
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
		
		$blade.AssignedToDn -match '(org-root/ls-)(?<computername>.*)' | Out-Null
		$obj.Hostname = $matches.computername
		
		
		Write-Output $obj
		
		
	}
	END
	{

	}	

}

<#
.SYNOPSIS
Manages the blue locator led on a UCS blade 
Version 1.00

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function set-UcsLocatorLed {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.ComputeBlade]$blade
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		Write-verbose "Turning on locator led for blade $($blade.serial)"
		get-UcsCentralEquipmentLocatorLedOperation -dn $bladeLocatorDn | set-UcsCentralEquipmentLocatorLedOperation -AdminState off -force | Out-Null
		Write-Host "Turning off locator led for $serial`n`n" -ForegroundColor Green
	}
	END
	{

	}	

}


<#
.SYNOPSIS
Manages ABC Operations
Watches an unassociate action and returns when finished

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
GET-ACME -thisvar "Hello" -thatvar 10

#>

function watch-UcsBladeDisassociate {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.ComputeBlade]$blade,
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.UcsCentralHandle]$ucsCentral
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$BladeMapping = get-BladeComputeSystemMapping -blade $blade -ucscentral $ucscentral
		
		Do
		{
			$bladeStatus = Get-UcsCentralBlade -serial $blade.serial -ucscentral $ucscentral
			Write-Host "Waiting for $($BladeMapping.bladeserial)|$($BladeMapping.hostname) to disassociate ($($bladeStatus.Association)|$($bladeStatus.Availability))"
			sleep 30
		}
		until ($bladeStatus.association -eq 'none')
		
	}
	END
	{

	}
	
}


<#
.SYNOPSIS
Watches an associate action and returns when finished

.DESCRIPTION


.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
GET-ACME -thisvar "Hello" -thatvar 10

#>

function watch-UcsBladeAssociate {
[CmdletBinding(supportsshouldprocess=$True)]
param (
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.ComputeBlade]$blade,
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.UcsCentralHandle]$ucsCentral
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		$BladeMapping = get-BladeComputeSystemMapping -blade $blade -ucscentral $ucscentral
		
		do
		{
			$profile = Get-UcsCentralServiceProfile -dn $blademapping.assignedtodn -ucscentral $ucsCentral
			write-host "Waiting for $($blademapping.BladeSerial) to Associate ($($profile.AssocState)|$($profile.configstate)|$($profile.AssignState))"
			sleep 30
		}
		until ($profile.AssocState -eq 'associated')
		
	}
	END
	{

	}	

}


<#
.SYNOPSIS
checks to see if the blade is powered on an asks you if you want to power it off
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
GET-ACME -thisvar "Hello" -thatvar 10

#>

function Test-UcsServiceProfilePowerStatus {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.LsServer]$bladeServiceProfile,
	[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
	[ValidateNotNullOrEmpty()]
	[Cisco.UcsCentral.UcsCentralHandle]$ucsCentral
)

	BEGIN
	{

	}
	PROCESS	
	{
		
		if (($bladeServiceProfile | get-UcsCentralServerPower).state -eq 'up')
		{
			$BladeSerial = (get-ucscentralblade -ucscentral $ucsCentral -dn $bladeServiceProfile.pndn).serial
			$answer = promptyn -question "`nBlade $($bladeServiceProfile.name)|$BladeSerial is still powered on, do you want to force a power off (y/n)" -foregroundcolor Green
			if ($answer -eq 'y')
			{
				$bladeServiceProfile | set-UcsCentralServerPower -State down -force
				while (($bladeServiceProfile | get-UcsCentralServerPower).state -ne 'Down')
				{
					Write-Host "Waiting for $($bladeServiceProfile.name)|$BladeSerial to power down $(get-date)"
					sleep 10
				}
			}
			else
			{
				Break
			}
		}
		
	}
	END
	{

	}	

}

function switch-UnassociatedBlade
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
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[Cisco.UcsCentral.ComputeBlade]$blade
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$bladeSerial = $blade.serial
		Write-host "Blade OperState $bladeSerial is $($blade.operstate)"
		
		$blade | Get-UcsCentralLocatorLed | set-UcsCentralEquipmentLocatorLedOperation -AdminState on -force | Out-Null
		
		Write-Host "Turning on locator led"
		
		$answer = promptyn -question "`n`nHas the datacenter engineer finished swapping the blade? (y/n)" -foregroundcolor Green
		if ($answer -eq 'Y')
		{
			Write-Host "Blade has been swapped, exiting script.."
		}
		else
		{
			Write-Host "Blade not swapped, exiting script..."
		}
		
		Write-Host "Turning off locator led for $bladeSerial"
		$blade | Get-UcsCentralLocatorLed | set-UcsCentralEquipmentLocatorLedOperation -AdminState off -force | Out-Null
		
	}
	
	End
	{
		
	}
}
