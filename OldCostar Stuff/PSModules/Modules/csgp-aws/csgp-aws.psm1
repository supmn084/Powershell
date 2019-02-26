
#REQUIRES -Version 2.0

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"



<#
.SYNOPSIS
Adds new volumes to an ec2 instance


.DESCRIPTION

.EXAMPLE
Mount to a drive letter
$volAdd =  New-Ec2Vol -volname server1-test1 -size 1 -az us-east-1a -computer AP50SQLTPRD581 -driveletter X -serverRole SQL -verbose 

.EXAMPLE
Mount to an empty folder (will create if does not exist)
$volAdd =  New-Ec2Vol -volname server1-test1 -size 1 -az us-east-1a -computer AP50SQLTPRD581 -mountpoint c:\mnt\myfolder -serverRole SQL -verbose 

#>

function New-Ec2Vol {
[CmdletBinding(supportsshouldprocess=$True)]
param(
		[parameter(Mandatory=$True,ValueFromPipeline= $False,ValueFromPipelineByPropertyName= $False)]
		[ValidateNotNullOrEmpty()]
		[string]$volname,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$size,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$az,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Computer,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("gp2", "io1")]
		[string]$volumetype,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$devicename, # like /dev/xvdf
		[parameter(Mandatory = $false, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$driveLetter, # like E
		[parameter(Mandatory = $false, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$mountPoint, # like "e:\mnt\myDirectory"
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("App", "Web", "SQL")]
		[string]$serverRole, # like App, Web or SQL
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[int]$iops  # number of provisioned iops
)

	BEGIN
	{
		if ((! $mountPoint) -and (! $driveLetter))
		{
			Write-Error "You must supply `$mountPoint or `$driveLetter and not both"	
		}
	}
	PROCESS
	{
		
		$az -match '(?<region>\w\w-\w+-\d)(\w)' | Out-Null # get the region from the AZ
		$region = $matches.region
		Write-Verbose "AZ:$az|Region:$region"
		
		try
		{
			$beforeDisks = Invoke-Command -ComputerName $Computer -ScriptBlock { get-disk }
		}
		catch
		{
			Write-Error "Unable to contact $computer via WMI: $_"	
		}
		
		# Get the instance that we want to mount the new volume to
		$i = get-ec2instance -region $region -Filter @( @{ Name = "tag:Name"; Value = "$computer" }; @{ name = 'instance-state-name'; value = 'running' })
		if (! $i)
		{
			Write-Error "Error getting instance info for $computer"
		}
		$instanceId = $i.instances.instanceid
		
		# Get the next device mapping like /dev/xvdX		
		$newMapping = get-NextDeviceName -instance $instanceId -region $region
		
		if (! $iops)
		{
			# Create non-provisioned IOPS volume
			$vol = New-EC2Volume -region $region -size $size -VolumeType $volumetype -AvailabilityZone $az
		}
		else
		{
			# Volume should be provisioned iops
			$vol = New-EC2Volume -region $region -size $size -VolumeType $volumetype -AvailabilityZone $az -iops $Iops
			
		}
		# Tag it
		New-EC2Tag -region $region -Resource @($vol.volumeId) -Tag @(@{ Key = "Name"; Value = $VOLNAME })
		
		# Wait until the new volume is available
		do
		{
			sleep 5
			Write-verbose "Checking to see if volume $($vol.volumeid) is available after creation: $(get-date)"
			$volStatus = get-ec2volume -region $region -volumeid $vol.volumeid
		}
		until ($volStatus.state -eq 'available')
		Remove-Variable volstatus -Confirm:$false
		
		
		# add to the instance
		if ($devicename)
		{
			$newMapping = $devicename
		}
		$volAdd = add-ec2volume -region $region -instanceid $i.Instances.instanceid -volumeid $vol.volumeId -Device $newMapping
		
		# Wait until the new volume is actually attached to the instance
		do
		{
			sleep 5
			Write-verbose "Checking to see if volume is attached to instance $($i.Instances.instanceid): $(get-date)"
			$volStatus = get-ec2volume -region $region -volumeid $vol.volumeid
			# Write-Verbose "`t$($volStatus.state)"
		}
		until ($volStatus.state -eq 'in-use')
		Remove-Variable volstatus -Confirm:$false
		
		# Should have one additional disk (RAW)
		$afterDisks = Invoke-Command -ComputerName $Computer -ScriptBlock { get-disk }
		
		# $newDisk will have the single Microsoft.Management.Infrastructure.CimInstance#ROOT/Microsoft/Windows/Storage/MSFT_Disk that has been added to the server
		$differenceDisks = compare-object -ReferenceObject $beforeDisks -DifferenceObject $afterDisks
		$NewDisk = $differenceDisks.InputObject
		
		if ($serverRole -match 'APP|WEB')
		{
			$ntfsClusterSize = 4096
		}
		else
		{
			$ntfsClusterSize = 65536
		}
		
		# tell the remote computer to initialize and format the disk (GPT) for all.
		
		if ($driveLetter)
		{
			Write-Verbose "Mounting $driveLetter\$VOLNAME"
			$ntfsVolumeInfo = Invoke-Command -ComputerName $Computer -Args $NewDisk, $driveLetter, $VOLNAME, $ntfsClusterSize -ScriptBlock { $args[0] | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -DriveLetter $args[1] -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel $args[2] -AllocationUnitSize $args[3] -Confirm:$false }
		}
		elseif ($mountPoint)
		{
			Write-Verbose "Mounting $mountpoint"
			$mkdirResult = invoke-command -ComputerName $Computer -Args $mountPoint -ScriptBlock { mkdir $args[0] -ErrorAction:"SilentlyContinue" }
			$ntfsVolumeInfo = Invoke-Command -ComputerName $Computer -Args $NewDisk, $mountPoint, $VOLNAME, $ntfsClusterSize -ScriptBlock {  $args[0] | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize | Add-PartitionAccessPath –AccessPath $args[1] -passthru | Format-Volume -FileSystem NTFS -NewFileSystemLabel $args[2] -AllocationUnitSize $args[3] -Confirm:$false }
		}
		else
		{
			Write-Error "Did not find `$driveLetter or `$mountpoint parameters, quitting"	
		}
		
		
		Write-Output $ntfsVolumeInfo
		
	}
	END
	{

	}	

}

function get-NextDeviceName
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
		[string[]]$instance,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$region
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$i = get-ec2instance -region $region -instance $instance
		$nameFromTag = ($i.Instances.tags | ? { $_.key -eq 'name' }).value
		Write-Verbose "$instance|$nameFromTag"
		
		if (! $i)
		{
			Write-Error "Error getting instance info for $computer"
		}
		
		#$blockMappings = $i.Instances.BlockDeviceMappings | ? { $_.DeviceName -like "/dev/xvd*" }
		# This will capture the root device like /dev/sda1 as well as any other devies
		$blockMappings = $i.Instances.BlockDeviceMappings
		
		if (! $blockMappings)
		{
			#Write-Error "There are no mappings like /dev/xvd*"
			
		}
		
		# device letters /dev/xvd[f-z] as suggested by amazon
		$deviceLetters = 102..122 | foreach { [char]$_ }
		
		# Add each existing block mapping to a hash which will allow us to use .containskey() to check for next available letter
		$existingMappings = @{ }
		foreach ($mapping in $blockMappings.DeviceName)
		{
			$existingMappings.Add("$mapping", 'InUse')
		}
		
		# Loop through device letters and find one that is not being used by the existing devices
		foreach ($letter in $deviceLetters)
		{
			$mappingKey = "/dev/xvd$letter"
			if ($existingMappings.ContainsKey($mappingKey))
			{
				Write-verbose "$mappingKey already in use, skipping..."
				continue
			}
			else
			{
				$newMapping = $mappingKey
				Write-verbose "$mappingKey is available..."
				break
			}
		}
		
		Write-verbose "will use $newMapping for add-ec2volume "
		Write-Output $newMapping
	}
	
	End
	{
		
	}
}
