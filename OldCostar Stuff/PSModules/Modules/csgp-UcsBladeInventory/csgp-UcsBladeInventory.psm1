#REQUIRES -Version 2.0

#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"
#$VerbosePreference = "Continue"

function Import-PSCredential
{
	param ($Path = "credentials.enc.xml")
	# See http://halr9000.com/article/531 for info on exporting.
	
	# Import credential file
	$import = Import-Clixml $Path
	
	# Test for valid import
	if (!$import.UserName -or !$import.EncryptedPassword)
	{
		Throw "Input is not a valid ExportedPSCredential object, exiting."
	}
	$Username = $import.Username
	
	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
	
	# Build the new credential object
	$Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
	$Credential	# return to caller
}

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
		
		foreach ($computeSystem in $computeSystems )
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

function get-bladeinventory
{
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
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[System.Object[]]$UcsChassis,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[int]$numSlotsPerChassis,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[hashtable]$ComputeSystemHash,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Cisco.UcsCentral.UcsCentralHandle]$ucsCentral
		
	)
	
	BEGIN
	{
		
		$disks = Get-UcsCentralStorageLocalDisk -ucsCentral $ucsCentral
		Write-Verbose "test"
		# fyi the DN used here looks like: compute/sys-1007/chassis-1/blade-1/board/storage-SAS-1/disk-2
		
	}
	PROCESS
	{
		
		foreach ($chassis in $UcsChassis)
		{
			Write-verbose "UCS Chassis: $($chassis.dn)"
			
			for ($slot = 1; $slot -le $numSlotsPerChassis; $slot++)
			{
				[int]$chassisId = $chassis.id
				$testThisBladeId = "$chassisid/$slot"
				
				if ($blade = ($chassis | Get-UcsCentralBlade | ? { $_.serverID -eq $testThisBladeId }))
				{
					$bladePresentInSlot = $true
					
					$blade.dn -match 'compute/sys-(?<BladeClusterId>\d+)(/\w+-\d+)' | out-null
					[int]$bladeClusterId = $matches.BladeClusterId
					$ucsClusterName = $ComputeSystemHash.item($bladeClusterId).Clustername
					$ucsDatacenterName = $ComputeSystemHash.item($bladeClusterId).DataCenter
					
					new-bladeReport -bladePresentInSlot $bladePresentInSlot -blade $blade -chassis $chassisId -slot $slot -ucsclusterName $ucsClusterName -ucsdatacenterName $ucsDatacenterName -disks $disks
				}
				else
				{
					$bladePresentInSlot = $false
					
					$chassis.dn -match 'compute/sys-(?<ChassisComputeSystemId>\d+)(/\w+-\d+)' | out-null
					[int]$ChassisComputeSystemId = $matches.ChassisComputeSystemId
					$ucsClusterName = $ComputeSystemHash.item($ChassisComputeSystemId).Clustername
					$ucsDatacenterName = $ComputeSystemHash.item($ChassisComputeSystemId).DataCenter
					
					new-bladeReport -bladePresentInSlot $bladePresentInSlot -chassis $chassisId -slot $slot -ucsclusterName $ucsClusterName -ucsdatacenterName $ucsDatacenterName
				}
				
				Write-verbose "Chassis ID: $testThisBladeId, BladePresent: $bladePresentInSlot"
			}
		}
		
	}
	END
	{
		
	}
	
}

function new-bladeReport
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
		[parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[Cisco.UcsCentral.ComputeBlade]$blade,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[boolean]$bladePresentInSlot,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[int]$chassis,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[int]$slot,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$ucsClusterName,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$ucsDatacenterName,
		[parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		$disks
		
	
		
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$obj = @()
		$obj = "" | Select-Object Hostname, DataCenter, ClusterName, ChassisNum, Slot, Association, ManagedBy, Model, Disks, DiskVendor, Cores, Threads, Totalmemory, OperState, Serial
		
			
		try
		{
			$blade.AssignedToDn -match '(.*-)(?<hostname>.*)' | Out-Null
			$obj.Hostname = $matches.hostname
		}
		catch
		{
			$obj.Hostname = "NO-HOSTNAME"
		}
		
		if ($bladePresentInSlot)
		{
			$obj.Model = $blade.model
			$obj.Cores = $blade.numofcores
			$obj.Threads = $blade.numofThreads
			$obj.OperState = $blade.OperState
			$obj.Serial = $blade.serial
			$obj.TotalMemory = $blade.totalmemory
			
			$obj.ChassisNum = $chassisId
			$obj.Slot = $slot
			$obj.Association = $blade.Association
			if ($blade.Association -eq 'associated')
			{
				# blade is associated and we need to find out if it's associated to ucsm or ucsc
				if (get-ucscentralserviceprofile -pndn $blade.dn)
				{
					# found a ucsc service profile, ucsc managed
					$obj.ManagedBy = $blade.UcsCentral
				}
				else
				{
					# get-ucscentralserviceprofile was empty, means blade is locally managed
					$obj.ManagedBy = 'UCSM'
				}
			}
			
			$obj.Clustername = $ucsClusterName
			$obj.Datacenter = $ucsDatacenterName
			
			$obj.Disks = ($disks | ? { (($_.dn -like "$($blade.dn)*") -and ($_.blocksize -ne 'unknown')) } | measure-object).count
			$diskVendor = ""
			$diskVendorObj = $disks | ? { (($_.dn -like "$($blade.dn)*") -and ($_.blocksize -ne 'unknown')) } | select Vendor
			foreach ($Vendor in $diskVendorObj)
			{
				$vendorName = "$($vendor.vendor),"
				$diskVendor += $vendorName
			}
			
			$obj.diskVendor = $diskVendor
			
		}
		else
		{
			$obj.Hostname = 'EMPTY-SLOT'
			$obj.Model = ""
			$obj.Cores = ""
			$obj.Threads = ""
			$obj.OperState = ""
			$obj.Serial = ""
			$obj.TotalMemory = ""
			$obj.Association = 'empty-slot'
			$obj.OperState = 'empty-slot'
			$obj.ManagedBy = ""
			$obj.Disks = ""
			$obj.diskVendor = ""
			$obj.Clustername = $ucsClusterName
			$obj.Datacenter = $ucsDatacenterName
			
			$obj.ChassisNum = $chassisId
			$obj.Slot = $slot
		}
		
		$report += $obj
		Write-Output $report
		
		
	}
	
	End
	{
		
	}
}

function Clear-CoStarSharepointUcsList
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
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$listName,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[Microsoft.PowerShell.Commands.NewWebserviceProxy.AutogeneratedTypes.WebServiceProxy1etops__vti_bin_lists_asmx_wsdl.Lists]$service
		
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$listRows = get-spListItems -listName $listName -service $service
		if (($listRows | measure-object).count -gt 0)
		{
			$listRows | % { remove-spListItem -listName $listName -rowID $_.ows_ID -service $service }
		}
			
		
	}
	
	End
	{
		
	}
}

function Update-CoStarSharepoint
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
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[string]$listName,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[Microsoft.PowerShell.Commands.NewWebserviceProxy.AutogeneratedTypes.WebServiceProxy1etops__vti_bin_lists_asmx_wsdl.Lists]$service,
		[parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[psobject]$report
		
	)
	
	begin
	{
		
	}
	
	process
	{
		
#		$listRows = get-spListItems -listName $listName -service $service
#		if (($listRows | measure-object).count -gt 0)
#		{
#			$listRows | % { remove-spListItem -listName $listName -rowID $_.ows_ID -service $service }
#		}
		
		foreach ($bladeRow in $report)
		{
			# Hostname, DataCenter, ClusterName, ChassisNum, Slot, Association, Model, Disks, DiskVendor, Cores, Threads, Totalmemory, OperState, Serial
			$xmlFields = @"
			"<Field Name='Title'>$($bladeRow.Hostname)</Field>" 
			"<Field Name='Datacenter'>$($bladeRow.Datacenter)</Field>" 
			"<Field Name='ClusterName'>$($bladeRow.ClusterName)</Field>" 
			"<Field Name='ChassisNum'>$($bladeRow.ChassisNum)</Field>" 
			"<Field Name='Slot'>$($bladeRow.Slot)</Field>" 
			"<Field Name='Association'>$($bladeRow.Association)</Field>" 
			"<Field Name='ManagedBy'>$($bladeRow.ManagedBy)</Field>" 
			"<Field Name='Model'>$($bladeRow.Model)</Field>" 
			"<Field Name='Disks'>$($bladeRow.Disks)</Field>" 
			"<Field Name='DiskVendor'>$($bladeRow.DiskVendor)</Field>" 
			"<Field Name='Cores'>$($bladeRow.Cores)</Field>" 
			"<Field Name='Threads'>$($bladeRow.Threads)</Field>" 
			"<Field Name='Totalmemory'>$($bladeRow.Totalmemory)</Field>" 
			"<Field Name='OperState'>$($bladeRow.OperState)</Field>" 
			"<Field Name='Serial'>$($bladeRow.Serial)</Field>" 	    		
"@
			
			new-spListItem -listName $listName -xmlFields $xmlFields -service $service
		}
		
		
	}
	
	End
	{
		
	}
}

