# This module is used by the VMDeploy.ps1 script 

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"	# default to showing all verbose info

function get-spListAllFieldsById
{
	# Connect to the ServerRequest list and get complete row info for a given ID
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$uri,
		[parameter(Mandatory = $true)]
		[string]$spList, # Sharepoint List
		[parameter(Mandatory = $true)]
		[int]$id
	)
	
	# create the web service
	write-verbose "LOG: Accessing list $spList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	# Get rows
	$listRows = get-spListItems -listname $spList -service $service | ? { $_.ows_ID -eq $id }
	write-verbose "LOG: got list row, found ID $($listRows.ows_id), Title: $($listRows.ows_title)"
	
	Write-Output $listRows
}

function new-spServerRequestFields
{
	<#
		.SYNOPSIS
			This function takes in the raw sharepoint row and adds important
			fields to an Object that we'll use quite frequently.
			Note: does not include disks, new-vmHardDiskTable does that for us in a separate table

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spRequestAllFieldsObj,
		[parameter(Mandatory = $true)]
		$RamGb
	)
	
	$listRows = $spRequestAllFieldsObj
	
	# Make sure to trim() every property or you will allow a user to create objects with spaces at the end or beginning (bad)
	
	$r = @()  # r is short for "request"
	$r = "" | Select-Object ID, Title, ITProject, ITProjectDescription, ITEnvironment, ITSubEnvironment, ITProjectManager, ITProjectDirector, DataCenterCountry, DataCenterLocation, BackupRequirements, NetIQMonitoringRequirements, ComputerType, CpuCnt, RamGB, LocalAdmins, ServerRole, ServerRoleAppended, OperatingSystem, Hostname, IpAddressInfo, NetworkSecurityZone, ApplicationName, CotsWithSql, VmToClone, ServerRequester, Approved, EolDate, MaintenanceGroup, CreateFirewallObject, SanFailureDomain
	
	$r.ID = $listRows.ows_id
	$r.Title = $listRows.ows_title.trim()
	$r.ITProject = $listRows.ows_ITProject
	
	if ($listRows.ows_ITProjectDescription -like "*&*")
	{
		# Remove any amp & and replace with 'and'.  My sharepoint modules
		#	don't know how to inssert a string with an &
		$itProjectDescriptionClean = $listRows.ows_ITProjectDescription -replace "&", "and"
		$r.ITProjectDescription = $itProjectDescriptionClean
	}
	else
	{
		$r.ITProjectDescription = $listRows.ows_ITProjectDescription
	}
	$r.ITEnvironment = $listRows.ows_ITEnvironment
	$r.ITSubEnvironment = $listRows.ows_ITSubEnvironment
	$r.ITProjectManager = $listRows.ows_ITProjectManager
	$r.ITProjectDirector = $listRows.ows_ITProjectDirector
	$r.DataCenterCountry = $listRows.ows_DataCenterCountry
	$r.DataCenterLocation = $listRows.ows_DataCenterLocation
	$r.BackupRequirements = $listRows.ows_BackupRequirements
	$r.NetIQMonitoringRequirements = $listRows.ows_NetIQMonitoringRequirements
	$r.ComputerType = $listRows.ows_ComputerType
	$r.CpuCnt = $listRows.ows_CpuCnt
	if ($RamGB)
	{
		# Support override
		$r.RamGB = $RamGB
	}
	else
	{
		$r.RamGB = $listRows.ows_RamGB
	}
	
	$r.LocalAdmins = $listRows.ows_LocalAdmins
	$r.ServerRequester = $listRows.ows_Author
	$r.ServerRole = $listRows.ows_ServerRole
	$r.OperatingSystem = $listRows.ows_OperatingSystem
	$r.Hostname = $listRows.ows_Hostname.trim()
	$r.IpAddressInfo = $listRows.ows_IpAddressInfo.trim()
	$r.NetworkSecurityZone = $listRows.ows_NetworkSecurityZone
	$r.ApplicationName = $listRows.ows_ApplicationName.trim()
	$r.CotsWithSql = try { $listRows.ows_CotsWithSql }
	catch { '0' }
	$r.VmToClone = try { $listRows.ows_VmToClone.trim() }
	catch { }
	$r.Approved = $listRows.ows_Approved
	$listRows.ows_ServerRequester -match '(\d+;\#)(.*)' | out-null # Clean up email address
	$r.ServerRequester = $Matches[2]
	try
	{
		$r.EolDate = $listRows.ows_EolDate
	}
	catch
	{
		$r.EolDate = '2050-01-01 00:00:00'
	}
	$r.MaintenanceGroup = $listRows.ows_MaintenanceGroup
	$r.CreateFirewallObject = $listRows.ows_CreateFirewallObject
	$r.SanFailureDomain = $listRows.ows_SanFailureDomain
	
	# Combine WEB or APP into WEBAPP. This will allow us to remove about 1/3 of the rows in the $networkDefinition hash table
	# the $networkDefinition will contain a single WEBAPP row instead of individual WEB and APP roles
	if ( ($r.serverRole -eq 'WEB') -or ($r.serverRole -eq 'APP') )
	{
		$r.ServerRoleAppended = 'WEBAPP'
	}
	else
	{
		$r.ServerRoleAppended = $r.ServerRole	
	}
		
	Write-Output $r
}

<#
.SYNOPSIS
This function will figure out which patch maintenance group this server should belong to


.DESCRIPTION
Normally we'll just accept the users input but if AUTOSELECT-A-B is selected we'll have to 
balance the request between A and B.

.PARAMETER


.EXAMPLE

#>
function Select-MaintenanceGroup {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	$spBuildData
)

	BEGIN
	{

	}
	PROCESS	
	{
		$userSelectedMaintenanceGroup = $spBuildData.MaintenanceGroup
		
	}
	END
	{

	}	

}

function wait-VmCustomizationToComplete {
	#Waiting for OS customization to complete
	#Posted on August 1, 2012 by Alan Renouf	
	# Lifted from the PowerCli blog
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
   		[VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]] $vmList,
		
		[Parameter(Position=1, Mandatory=$true)]
		[ValidateNotNull()]
		[System.Int32] $timeoutSeconds = 1200, 
		
		[Parameter(Position=2, Mandatory=$true)]
		[ValidateNotNull()]
		[System.Int32] $id

	)
	begin {
			
		# constants for status
		$STATUS_VM_NOT_STARTED = "VmNotStarted"
		$STATUS_CUSTOMIZATION_NOT_STARTED = "CustomizationNotStarted"
		$STATUS_STARTED = "CustomizationStarted"
		$STATUS_SUCCEEDED = "CustomizationSucceeded"
		$STATUS_FAILED = "CustomizationFailed"

		$STATUS_NOT_COMPLETED_LIST = @( $STATUS_CUSTOMIZATION_NOT_STARTED, $STATUS_STARTED )
 
		# constants for event types     
		$EVENT_TYPE_CUSTOMIZATION_STARTED = "VMware.Vim.CustomizationStartedEvent"
		$EVENT_TYPE_CUSTOMIZATION_SUCCEEDED = "VMware.Vim.CustomizationSucceeded"
		$EVENT_TYPE_CUSTOMIZATION_FAILED = "VMware.Vim.CustomizationFailed"
		$EVENT_TYPE_VM_START = "VMware.Vim.VmStartingEvent"

		# seconds to sleep before next loop iteration
		$WAIT_INTERVAL_SECONDS = 30
		 

	}
	process {

	   # the moment in which the script has started
	   # the maximum time to wait is measured from this moment
	   $startTime = Get-Date
	  
	   # we will check for "start vm" events 5 minutes before current moment
	   $startTimeEventFilter = $startTime.AddMinutes(-5)
	  
	   # initializing list of helper objects
	   # each object holds VM, customization status and the last VmStarting event
	   $vmDescriptors = New-Object System.Collections.ArrayList
	   foreach($vm in $vmList) {
	      write-verbose "Start monitoring customization process for vm '$vm'"
	      $obj = "" | select VM,CustomizationStatus,StartVMEvent
	      $obj.VM = $vm
	      # getting all events for the $vm,
	      #  filter them by type,
	      #  sort them by CreatedTime,
	      #  get the last one
	      $obj.StartVMEvent = Get-VIEvent -Entity $vm -verbose:$false -Start $startTimeEventFilter | `
	         where { $_ -is $EVENT_TYPE_VM_START } |
	         Sort CreatedTime |
	         Select -Last 1
	        
	      if (-not $obj.StartVMEvent) {
	         $obj.CustomizationStatus = $STATUS_VM_NOT_STARTED
	      } else {
	         $obj.CustomizationStatus = $STATUS_CUSTOMIZATION_NOT_STARTED
	      }
	     
	      [void]($vmDescriptors.Add($obj))
	   }        
	  
	   # declaring script block which will evaulate whether
	   # to continue waiting for customization status update
	   $shouldContinue = {
	      # is there more virtual machines to wait for customization status update
	      # we should wait for VMs with status $STATUS_STARTED or $STATUS_CUSTOMIZATION_NOT_STARTED
	      $notCompletedVms = $vmDescriptors | `
	         where { $STATUS_NOT_COMPLETED_LIST -contains $_.CustomizationStatus }

	      # evaulating the time that has elapsed since the script is running
	      $currentTime = Get-Date
	      $timeElapsed = $currentTime – $startTime
	     
	      $timoutNotElapsed = ($timeElapsed.TotalSeconds -lt $timeoutSeconds)
	     
	      # returns $true if there are more virtual machines to monitor
	      # and the timeout is not elapsed
	      return ( ($notCompletedVms -ne $null) -and ($timoutNotElapsed) )
	   }
	     
	   while (& $shouldContinue) {
	      foreach ($vmItem in $vmDescriptors) {
	         $vmName = $vmItem.VM.Name
			 $host.ui.RawUI.WindowTitle = "MONITORING CUSTOMIZATION: $vmName | ID: $id | $(Get-Date)"
	         switch ($vmItem.CustomizationStatus) {
	            $STATUS_CUSTOMIZATION_NOT_STARTED {
	               # we should check for customization started event
	               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime -Verbose:$false
	               $startEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_STARTED }
	               if ($startEvent) {
	                  $vmItem.CustomizationStatus = $STATUS_STARTED
	                  write-verbose "Customization for VM '$vmName' has started"
	               }
	               break;
	            }
	            $STATUS_STARTED {
	               # we should check for customization succeeded or failed event
	               $vmEvents = Get-VIEvent -Entity $vmItem.VM -Start $vmItem.StartVMEvent.CreatedTime -Verbose:$false
	               $succeedEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_SUCCEEDED }
	               $failedEvent = $vmEvents | where { $_ -is $EVENT_TYPE_CUSTOMIZATION_FAILED }
	               if ($succeedEvent) {
	                  $vmItem.CustomizationStatus = $STATUS_SUCCEEDED
	                  Write-verbose "Customization for VM '$vmName' has successfully completed"
	               }
	               if ($failedEvent) {
	                  $vmItem.CustomizationStatus = $STATUS_FAILED
	                  Write-verbose "Customization for VM '$vmName' has failed"
	               }
	               break;
	            }
	            default {
	               # in all other cases there is nothing to do
	               #    $STATUS_VM_NOT_STARTED -> if VM is not started, there's no point to look for customization events
	               #    $STATUS_SUCCEEDED -> customization is already succeeded
	               #    $STATUS_FAILED -> customization
	               break;
	            }
	         } # enf of switch
	      } # end of the freach loop
	     
	      Write-verbose "Waiting for customization, sleeping for $WAIT_INTERVAL_SECONDS seconds $(get-date)"
	      Sleep $WAIT_INTERVAL_SECONDS
	   } # end of while loop
	  
	   # preparing result, without the helper column StartVMEvent
	   $result = $vmDescriptors | select VM,CustomizationStatus
	   # return $result
	   Write-Output $result
	   
	}

	end {
		try {
		}
		catch {
		}
	}
}

function select-vmHostRandom {
	<#
		.SYNOPSIS
			This function randomly selects a single host from the given cluster.  VM will be deployed on this host

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[string]$vmClusterForDeployment
		)
	

	$vmClusterObj = get-cluster -name $vmClusterForDeployment -verbose:$false
	
	# Randomly select a connected host
	$vmHosts = @($vmClusterObj | get-vmhost -verbose:$false | ? { $_.ConnectionState -eq 'Connected' } )
	if (($vmhosts | measure-object).count -gt 1)
	{
		$vmHostObj = Get-Random -InputObject $vmHosts
	}
	else
	{
		# with the above get-random i would get this on a single node cluster
		# Get-Random : Cannot validate argument on parameter 'InputObject'. The argument is null or empty
		$vmHostObj = $vmHosts[0]
	}
	
	if (! $vmHostObj)	{
		Write-Error "Unable to find any 'connected' vmHosts in cluster $vmClusterForDeployment, exiting..."
		exit
	}
	
	#$vmHostForDeployment = ($vmHostObj).name # Get singular host name for deployment
	write-output $vmHostObj
}

function find-eligibleVmfsDatastores
{
	<#
		.SYNOPSIS
			This function will filter out any excluded vmfs datastores and 
			return a list of eligible datastores that we can deploy VMs on

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		# The vmhost name [sring]
		[parameter(Mandatory = $true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHostObj,
		# List of datastore partial strings that we should not deploy on
		[parameter(Mandatory = $true)]
		[array]$vmfsDatastoresToExclude,
		# The server build object
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		$spBuildData
	)
	
	$eligibleVmfsDatastores = @()
	
	$itEnvironment = $spBuildData.Itenvironment
	$itSubEnvironment = $spBuildData.ITSubenvironment
	$serverRole = $spBuildData.serverroleAppended
	$failuredomain = $spBuildData.SanFailureDomain
	
	# Get datastores in ascending freeSpaceGb
	$datastores = $vmHostObj | get-datastore -verbose:$false | sort FreeSpaceGb
	
	# Note: Below you will see a lot of -match or -notmatch for 'DEV|TST'
	# We are doing this because as of 8/18/2015 we are combining TST Integrated and TST Stand-Alone as
	# well as DEV Integrated and DEV Stand-Alone onto their own respective datastores.  Since (for example)
	# we will have TST Integrated and TST Stand-Alone servers on the same datastore I can't tag the datastore with
	# ITSubEnvironment because it is misleading to say the datastore is for Integrated when it will also host Stand-Alone
	# This is not a big deal, just have to work around it in a few cases below.
	
	foreach ($ds in $datastores)
	{
		try
		{
			$dsTagItEnvironment = ($ds | Get-TagAssignment -verbose:$false -Category ITEnvironment).tag.name
			
			if ($ITEnvironment -notmatch 'DEV|TST|BAT')
			{
                # DEV|TST|BAT environments don't need ItSubEnvironment but everything else does
				$dsTagItSubEnvironment = ($ds | Get-TagAssignment -verbose:$false -Category itSubEnvironment).tag.name
			}
			
			$dsTagServerRole = ($ds | Get-TagAssignment -verbose:$false -Category serverRole).tag.name
			
			$dsTagFailureDomain = ($ds | Get-TagAssignment -verbose:$false  -Category FailureDomain).tag.name
		}
		catch
		{
			Write-Verbose "$($ds.name) missing >=1 tags, skip..."
			continue
		}
		
		# If the failure domain on the DS does not match what the VM want's (A or B but not Auto-Select), skip this datastore.
		$isVmfsFailureDomainMatchingVMFailureDomain = Test-SanFailureDomain -VmfsDatastoreObj $ds -vmfailureDomain $failuredomain -spBuildData $spBuildData
		if ($isVmfsFailureDomainMatchingVMFailureDomain -eq $false)
		{
			Write-Verbose "$($ds.name) explicit VM FailureDomain did not match DS Failuredomain, skip.."
			continue # don't have a proper failuredomain match between vm and datastore, skip this datastore
		}
		
        # This if{} block is just helping with verbose messages to make troubleshooting easier
		Write-Verbose "Comparing tags between: $($ds.name)|$($spbuildData.Hostname)"
		if ($itEnvironment -notmatch 'DEV|TST|BAT')
		{
			# # DEV|TST|BAT environments don't need ItSubEnvironment but everything else does
			Write-Verbose "DS: $dsTagItEnvironment|$dsTagItSubEnvironment|$dsTagServerRole|$dsTagFailureDomain"
		}
		ELSE
		{
			# Must be DEV|TST|BAT and we don't care about ItSubEnvironment
			Write-Verbose "DS: $dsTagItEnvironment|N/A|$dsTagServerRole|$dsTagFailureDomain"
		}
		Write-Verbose "VM: $ItEnvironment|$ItSubEnvironment|$ServerRole|$FailureDomain"
		Write-Verbose "`n"
		
		# Add the datastore to the custom object
		if ($ITEnvironment -match 'DEV|TST|BAT')
		{
			# this VM will be deployed into a non-production datastore
			if (($dsTagItEnvironment -eq $itEnvironment) -and ($dsTagServerRole -eq $serverRole))
			{
				# on non-production environments we just need to match on $itEnvironment and $serverRole
				$eligibleVmfsDatastores += $ds
			}
		}
		elseif (($dsTagItEnvironment -eq $itEnvironment) -and ($dsTagItSubEnvironment -eq $itSubEnvironment) -and ($dsTagServerRole -eq $serverRole))
		{
			# this is not a DEV|TST|BAT datastore and we need to match $itEnvironment, $itSubEnvironment, $serverRole
			$eligibleVmfsDatastores += $ds
		}
		else
		{
			# else nothing	
		}
	
	}
	
	if (! $eligibleVmfsDatastores)
	{
		# We have looped through each datastore on the host and did not find any matching datastores with the proper tags
		if ($ITEnvironment -match 'DEV|TST|BAT')
		{
			# 3 tag error message for non-production
			Write-Error "No datastores found with tags matching VM requirement of  $ITEnvironment,$ServerRole,$FailureDomain"
		}
		else
		{
			# 4 tag error message for production
			Write-Error "No datastores found with tags matching VM requirement of  $ITEnvironment,$ItSubEnvironment,$ServerRole,$FailureDomain"
		}
	}
	
	write-output $eligibleVmfsDatastores
}

function select-datastore
{
<#
	.SYNOPSIS
		This function will select a proper datastore based on ServerRole

	.DESRIPTION
		select-datastore will try to select a datastore containing "WEBAPP" or
			"SQL".  If we have WEBAPP or SQL datastores but not enough space we 
			error out of the function
			
		If we don't find any WEBAPP or SQL datastores the function reverts back
			to the original datastore format seletion process selecting  whatever datastore is 
			available by selecting the datastore with the least amount of free 
			space
#>
	param (
		# The server build object
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		# The min amount of free space we need to maintain on the vmfs datastore
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[hashtable]$vmfsMinSpaceMb,
		# Total space requested for this VM
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$totalVMStorageRequestedMB,
		# Object of VMFS datastores that we can deploy a VM onto
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		$eligibleVmfsDatastores
	)
	
	[Boolean]$suitableDatastoreSelected = $false	# We have not yet selected a suitable datastore	
	
	# Use the normal selection process Itterate through each eligible datastore,
	# ordered by least to most space
	#	The goal is to fill up the datastore to capacity before selecting another
	#	datastore that has more free space
	
	foreach ($eligibleVmfsDatastore in $($eligibleVmfsDatastores | Sort-Object -Property FreeSpaceGb))
	{
		[boolean]$dataStoreHasEnoughFreeSpace = $false

		# Select a datastore with enough free space.
		#	If this datastore does not have enough free space (plus reserve)
		#		the function will throw a terminating error and catch{} will handle
		Write-Host ""
		Write-Verbose "Does $($eligibleVmfsDatastore.Name) have enough space for $totalVMStorageRequestedMB MB"
		try
		{
			# will return a VmfsDatastoreImpl for a single datastore that passed the test.  If it does not pass, we throw a terminating error for catch{}
			$ourDataStoreObj = test-DatastoreFreeSpace -VmfsDatastoreObj $eligibleVmfsDatastore -vmfsMinSpaceMb $vmfsMinSpaceMb.thin -totalVMStorageRequestedMB $totalVMStorageRequestedMB
			$dataStoreHasEnoughFreeSpace = $true
			break 	# we found the datastore with the least amount of space that will allow us to fit our VM, break out of loop and finish up
			
			
		}
		catch
		{
			# If we catch a terminating error in test-DatastoreFreeSpace we just
			#	move on to the next datastore ordered by free space and test that one, repeat, repeat.
			Write-Verbose "Not enough free + buffer`($($vmfsMinSpaceMb.thin)`)MB on $($eligibleVmfsDatastore.Name) for $totalVMStorageRequestedMB new MB, try next ds..."
			continue
		}		
	}
	
	
	if ($dataStoreHasEnoughFreeSpace -eq $false)
	{
		Write-Error "There are no datastores that have enough free space to support the request of $totalVMStorageRequestedMB MB"
	}
	else
	{
		Write-Verbose "Using Datastore $($ourDataStoreObj)"
		Write-Host ""
		Write-output $ourDataStoreObj
	}
}

function test-DatastoreFreeSpace
{
	<#
		.SYNOPSIS
			Adds up the requested disk space, looks at actual disk space and tells us if we have enouth space on the datastore

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[int]$totalVMStorageRequestedMB,
		[parameter(Mandatory = $true)]
		[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$vmfsDatastoreObj,
		[parameter(Mandatory = $true)]
		[int]$vmfsMinSpaceMb
	)
	
	$requestedMB = 0
	
	$datastoreFreeMB = ($vmfsDatastoreObj).FreeSpaceMB
	
	# reducing by $vmfsMinSpaceMb ensures we always leave this much space on the datastore no matter what
	$datastoreAllowedSpaceForUse = $datastoreFreeMB - $vmfsMinSpaceMb
	
	if ($totalVMStorageRequestedMB -lt $datastoreAllowedSpaceForUse)
	{
		Write-Verbose "OK: $($vmfsDatastoreObj), Avail MB for VM space: $datastoreAllowedSpaceForUse; Req(MB): $totalVMStorageRequestedMB; Reserved:$vmfsMinSpaceMb"
	}
	else
	{
		Write-Error "Not enough free space + $vmfsMinSpaceMb reserve on $($vmfsDatastoreObj) You are asking for $totalVMStorageRequestedMB, with $vmfsMinSpaceMb reserve in place we have $datastoreAllowedSpaceForUse available.  You may override to a another datastore using -Datastore [DATASTORENAME]"
		exit
	}
	
	Write-Output $vmfsDatastoreObj
}

function Test-SanFailureDomain
{
<#
	.SYNOPSIS
		This function will ensure that the failure domain selected by the VM is available on the selected VMFS datastore

	.DESRIPTION
		
#>
	param (
		# The server build object
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$VmfsDatastoreObj,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$vmfailuredomain
	)
	
	
	Write-Verbose "Testing to see if $($VmfsDatastoreObj.name) is in Failure Domain $vmfailuredomain ($($spbuildData.hostname))"
	
	try
	{
		$thisLunFailureDomain = (Get-TagAssignment -verbose:$false -Entity $VmfsDatastoreObj -Category failureDomain).tag.name
	}
	catch
	{
		Write-Error "VMFS $($VmfsDatastoreObj.name) does not have any assigned failureDomain tags"
	}
	
	# The vCenter administrator can set the lun tag to NoAutomation if they don't want this script to include it in the selection process
	if ($thisLunFailureDomain -eq 'NoAutomation')
	{
		Write-Verbose "$($VmfsDatastoreObj.name) has NoAutomation tag set, skipping"
		[boolean]$isVmfsFailureDomainMatchingVMFailureDomain = $False
		Write-Output $isVmfsFailureDomainMatchingVMFailureDomain
		return
	}
	
	# match the following situations
	# vm FD-A = vmfs FD-A
	# vm FD-B = vmfs FD-B
	# vm Auto = vmfs (FD doesn't matter)
	# vm FD-A/B = vmfs AUTO-SELECT
	# Multiple vmfs datastore on a single SAN pool should never intermix Auto-select and FD-A/B, all luns should be Auto-select -or- FD-A/B but not a mixture of both
	

	if ( ($thisLunFailureDomain -eq $vmfailuredomain) -or ($vmfailuredomain -eq 'AUTO-SELECT') -or ($thisLunFailureDomain -eq 'AUTO-SELECT') )
	{
		Write-Verbose "VM `($vmfailuredomain`) = $($VmfsDatastoreObj.name) `($thisLunFailureDomain`)|match!"
		[boolean]$isVmfsFailureDomainMatchingVMFailureDomain = $True
		Write-Output $isVmfsFailureDomainMatchingVMFailureDomain
	}
	elseif ($thisLunFailureDomain -ne $vmfailuredomain)  
	{
		Write-Verbose "VM = $vmfailuredomain|$($VmfsDatastoreObj.name) = $thisLunFailureDomain|skipping"
		[boolean]$isVmfsFailureDomainMatchingVMFailureDomain = $False
		Write-Output $isVmfsFailureDomainMatchingVMFailureDomain
	}
	

	
}

function test-vm {
	<#
		.SYNOPSIS
			This function runs a pre-flight check to see if the VM exists

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[string]$newComputerName,
		[parameter(Mandatory=$true)]
		[string]$deleteVm
		)
	
	# Make sure the VM we want to deploy does not already exist
	$vmCheck = Get-View -ViewType VirtualMachine -Filter @{"Name" = $newComputerName} -Verbose:$false
	
	if ( $vmCheck ) {
		if ($deleteVm -eq 'True')	{	# $true
			# You have chosen -deleteVm on the command line, so delete this VM
			if ($vmCheck.runtime.PowerState -eq 'poweredOn')	{
				Write-Verbose "You specified -deleteVm, stopping VM $newComputerName..."
				Stop-VM -VM $newComputerName -Confirm:$false -ErrorAction Stop  -verbose:$false| Out-Null
			}
			
			Write-Verbose "You specified -deleteVm, we will remove vm $newComputerName..."
			Remove-VM -VM $newComputerName -Confirm:$false -DeletePermanently -ErrorAction Stop -verbose:$false
			
		} else {	# $false, the default
			# The standard response, stop the script if the VM exists.
			Write-Error "VM $newComputerName already exists, use -deletevm to override and overwrite"
			exit
		}
	}
}

function Get-FolderByPath{
  <#
.SYNOPSIS  Retrieve folders by giving a path
.DESCRIPTION The function will retrieve a folder by it's
  path. The path can contain any type of leave (folder or
  datacenter).
.NOTES  Author:  Luc Dekens
.PARAMETER Path
  The path to the folder.
  This is a required parameter.
.PARAMETER Path
  The path to the folder.
  This is a required parameter.
.PARAMETER Separator
  The character that is used to separate the leaves in the
  path. The default is '/'
.EXAMPLE
  PS> Get-FolderByPath -Path "Folder1/Datacenter/Folder2"
.EXAMPLE
  PS> Get-FolderByPath -Path "Folder1>Folder2" -Separator '>'
#>
 
  param(
  [CmdletBinding()]
  [parameter(Mandatory = $true)]
  [System.String[]]${Path},
  [char]${Separator} = '/'
  )
 
  process{
    #if((Get-PowerCLIConfiguration).DefaultVIServerMode -eq "Multiple"){
	if ( (Get-PowerCLIConfiguration | ? {$_.DefaultViServerMode -eq 'multiple' }) ) {
      $vcs = $defaultVIServers
    }
    else{
      $vcs = $defaultVIServers[0]
    }
 
    foreach($vc in $vcs){
      foreach($strPath in $Path){
        $root = Get-Folder -Name Datacenters -Server $vc -verbose:$false
        $strPath.Split($Separator) | %{
          $root = Get-Inventory -Name $_ -Location $root -Server $vc -NoRecursion -Verbose:$false
          if((Get-Inventory -Location $root -NoRecursion -verbose:$false| Select -ExpandProperty Name) -contains "vm"){
            $root = Get-Inventory -Name "vm" -Location $root -Server $vc -NoRecursion -Verbose:$false
          }
        }
        $root | where {$_ -is [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]}|%{
          Get-Folder -Name $_.Name -Location $root.Parent -Server $vc -verbose:$false
        }
      }
    }
  }
}

function test-IPSameSubNet
{
	<#
	.SYNOPSIS
		Tests to see if the gateway and the computer IP are on the same network

	.DESCRIPTION
		

	.PARAMETER  ComputerIpAddress
		Ip address of the computer

	.PARAMETER  $GatewayIpAddress
		IP address of the gateway
	
	.PARAMETER  $NetworkMask
		Mask of the network


	.EXAMPLE
		PS C:\> test-IPSameSubNet -ComputerIpAddress 172.16.0.10 -GatewayIpAddress 172.16.3.2 -NetworkMask 255.255.252.0
		
		This example shows how to call the test-IPSameSubNet function with named parameters.

	
	.INPUTS
		Net.IPAddress

	.OUTPUTS
		System.boolean

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[Net.IPAddress]$ComputerIpAddress,
		[Parameter(Mandatory = $true)]
		[Net.IPAddress]$GatewayIpAddress,
		[Parameter(Mandatory = $true)]
		[Net.IPAddress]$NetworkMask
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
			if (($ComputerIpAddress.address -band $NetworkMask.address) -eq ($GatewayIpAddress.address -band $NetworkMask.address))
			{
				$true
			}
			else
			{
				$false
			}
			
		}
	
	catch
	{
	}
}
end {
		try {
		}
		catch {
		}
	}
}

function get-vmTemplateForDeployment
{
	<#
		.SYNOPSIS
			This function selects the proper VM template to clone based on datacenter and OS

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$vmSourceTemplateDefinition,
		[parameter(Mandatory = $true)]
		[string]$OperatingSystem
	)
	
	$osRequired = $spBuildData.OperatingSystem
	$dataCenterDestination = $spBuildData.DataCenterLocation
	$vmTemplateForDeployment = $vmSourceTemplateDefinition."$dataCenterDestination|$OperatingSystem"
	
	Write-Output $vmTemplateForDeployment
}

function initialize-vmTemplate
{
	# Get the object for our vm template we'll use for cloning
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$vmTemplateForDeployment
	)
	
	try
	{
		$vmTemplateObj = Get-Template -Name $vmTemplateForDeployment -ErrorAction Stop -verbose:$false
		#$hostDeployingTemplate = (get-vmhost -id $vmTemplateObj.hostid).name
		#Write-Verbose "LOG: $($vmTemplateObj.name) will be deployed from host $hostDeployingTemplate"
		write-verbose "LOG: VM template object info: $($vmTemplateObj.name), $($vmTemplateObj.id)"
	}
	catch
	{
		Write-Error "Template $vmTemplateForDeployment does not exist on $global:DefaultVIServer"
	}
	
	Write-Output $vmTemplateObj
}

function initialize-specName
{
	# Just creates a name for our temporary spec we'll use to deploy a vm
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$specBasicInfo,
		[parameter(Mandatory = $true)]
		[string]$newComputerName
	)
	
	# Crete a temporary spec name (string) for this deployment
	$vmDeploymentSpecName = "$($specBasicInfo.TmpSpecName)_$newComputerName"
	
	Write-Output $vmDeploymentSpecName
}

function remove-spec
{
	# Removes the _tmpSpec_[servername] spec if for some reason it still exists (script crashed or other error)
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$vmDeploymentSpecName
	)
	
	
	# remove the deployment spec for this VM if it already exists
	try
	{
		Get-OSCustomizationSpec -Name $vmDeploymentSpecName -ErrorAction Stop -verbose:$false| Out-Null
		write-verbose "LOG: Removing custom spec $vmDeploymentSpecName"
		Remove-OSCustomizationSpec -OSCustomizationSpec $vmDeploymentSpecName -Confirm:$false -verbose:$false| Out-Null
	}
	catch
	{
		# spec does not exist, fine...
	}
}

function publish-specWindows
{
	# Builds our custom spec for this VM
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$specBasicInfo,
		[parameter(Mandatory = $true)]
		[string]$vmDeploymentSpecName,
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$vmNetworkSettings,
		[parameter(Mandatory = $true)]
		[string]$adComputerAndAccessGrpDomainName
	)
	
	# finish building the name of the spec.  for example: _autospec_US.COSTAR.LOCAL
	$customizationSpectoClone = $specBasicInfo.CustomizationSpectoClone + "$adComputerAndAccessGrpDomainName"
	Write-Verbose "Will clone spec $customizationSpectoClone to $vmDeploymentSpecName on vCenter $($defaultviserver.name)"
	
	# Note: New-OSCustomizationSpec  converts the local admin password from encrypted to unencrypted.
	# Breaks local admin password and we can't login
	# These calls preserve the admin password properly while copying the spec
	# Unfortunately we have to have this spec be Peristent (shows up in vSphere GUI) for now
	write-verbose "We see the following custom specs on vCenter $($defaultviserver.name)"
	$csmSpecMgr = Get-View 'CustomizationSpecManager' -verbose:$false
	#$csmSpecMgr.info | ? { $_.name -match '^_autospec' } | % { Write-Verbose "$($_.name)" }
	$autoSpecs = $csmSpecMgr.info | ? { $_.name -like "_autospec*" }
	$autospecs | % { write-verbose "$($_.name)" }
	
	# duplicate the reference spec to a new spec and set to our temporary spec name
	$csmSpecMgr.DuplicateCustomizationSpec($customizationSpectoClone, $vmDeploymentSpecName)

	
	# Build a new spec object from our reference spec
	$spec = Get-OSCustomizationSpec -Name $vmDeploymentSpecName -ErrorAction Stop -verbose:$false
	
	# Perform further customization of our new spec, saving back to the new spec
	$spec = set-OSCustomizationSpec -OSCustomizationSpec $spec `
						 -ChangeSid:$true -ProductKey $specBasicInfo.productkey -LicenseMode $specBasicInfo.LicenseMode `
						 -FullName $specBasicInfo.fullname -OrgName $specBasicInfo.OrgName `
						 -TimeZone $specBasicInfo.TimeZone -Type Persistent -AutoLogonCount $specBasicInfo.AutoLogonCount `
						 -ErrorAction Stop -Confirm:$false -verbose:$false
	
	# Example of adding multiple GuiRunOnce commands (works)
	# -GuiRunOnce "reg delete 'HKLM\SOFTWARE\Network Associates\ePolicy Orchestrator\Agent' /v AgentGUID /f", "reg delete 'HKLM\SOFTWARE\Network Associates\ePolicy Orchestrator\Agent' /v MacAddress /f"
	
	# Our spec object has existing nic mappings, dhcp by default
	# Remove the existing Nic mapping so we can add our own
	Remove-OSCustomizationNicMapping -OSCustomizationNicMapping (Get-OSCustomizationSpec $spec -verbose:$false | Get-OSCustomizationNicMapping -verbose:$false) -Confirm:$false -verbose:$false | Out-Null
	# http://communities.vmware.com/message/1601869
	
	# Add our custom Nic mapping back into the spec
	if ($spBuildData.IPAddressInfo -eq 'DHCP')
	{
		Write-Verbose "IP Addressing will use DHCP"
		Get-OSCustomizationSpec $spec -verbose:$false | new-OSCustomizationNicMapping -verbose:$false | Set-OSCustomizationNicMapping -IpMode UseDhcp -verbose:$false | Out-Null	# for dhcp
	}
	elseif ($spBuildData.IPAddressInfo -as [Net.IPAddress])
	{
		Write-Verbose "IP Addressing will use IP $($spBuildData.IPAddressInfo)"
		# PortGroup,VLAN,NetworkID,NetworkGw,NetworkMask,Dns1,Dns2,ClusterShort
		Get-OSCustomizationSpec $spec -verbose:$false | new-OSCustomizationNicMapping -verbose:$false | `
		Set-OSCustomizationNicMapping -IpMode UseStaticIP `
									  -IpAddress $spBuildData.IpAddressInfo -SubnetMask $vmNetworkSettings.NetworkMask `
									  -DefaultGateway $vmNetworkSettings.NetworkGw `
									  -Dns $vmNetworkSettings.Dns1, $vmNetworkSettings.Dns2 -verbose:$false 
	}
	else
	{
		Write-Error "ERROR: IPAddressInfo from sharepoint is not valid"
		exit
	}
	
	# Once...a long time ago we were able to 'write-output $spec' and that contained every thing we needed
	# I think when static IP addresses are used it screws up the write-output.
	# Anyway, not a big deal, we just re-get the spec right after we finish this function
	
}

function publish-specLinux
{
	# Builds our Linux custom spec for this VM
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$specBasicInfo,
		[parameter(Mandatory = $true)]
		[string]$vmDeploymentSpecName,
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$vmNetworkSettings,
		[parameter(Mandatory = $true)]
		[string]$adComputerAndAccessGrpDomainName
	)
	
	# finish building the name of the spec.  for example: _autospec_US.COSTAR.LOCAL
	$customizationSpectoClone = $specBasicInfo.CustomizationSpectoClone + "$adComputerAndAccessGrpDomainName"
	Write-Verbose "Will clone spec $customizationSpectoClone to $vmDeploymentSpecName on vCenter $($defaultviserver.name)"
	
	# Note: New-OSCustomizationSpec  converts the local admin password from encrypted to unencrypted.
	# Breaks local admin password and we can't login
	# These calls preserve the admin password properly while copying the spec
	# Unfortunately we have to have this spec be Peristent (shows up in vSphere GUI) for now
	write-verbose "We see the following custom specs on vCenter $($defaultviserver.name)"
	$csmSpecMgr = Get-View 'CustomizationSpecManager' -verbose:$false
	$csmSpecMgr.info | ? { $_.name -match '^_autospec' } | select Name
	
	# duplicate the reference spec to a new spec and set to our temporary spec name
	$csmSpecMgr.DuplicateCustomizationSpec($customizationSpectoClone, $vmDeploymentSpecName)
	
	
	# Build a new spec object from our reference spec
	$spec = Get-OSCustomizationSpec -Name $vmDeploymentSpecName -ErrorAction Stop -verbose:$false 
	
	# Perform further customization of our new spec, saving back to the new spec
	$spec = set-OSCustomizationSpec -OSCustomizationSpec $spec -DnsServer $vmNetworkSettings.Dns1, $vmNetworkSettings.Dns2 -DnsSuffix $specBasicInfo.DnsSuffix -ErrorAction Stop -Confirm:$false -verbose:$false
	#-TimeZone $specBasicInfo.TimeZone -Type Persistent `
	
	
	# Our spec object has existing nic mappings, dhcp by default
	# Remove the existing Nic mapping so we can add our own
	Remove-OSCustomizationNicMapping -OSCustomizationNicMapping (Get-OSCustomizationSpec $spec -verbose:$false  | Get-OSCustomizationNicMapping -verbose:$false ) -Confirm:$false -verbose:$false | Out-Null
	# http://communities.vmware.com/message/1601869
	
	
	# Add our custom Nic mapping back into the spec
	if ($spBuildData.IPAddressInfo -eq 'DHCP')
	{
		Get-OSCustomizationSpec $spec -verbose:$false | new-OSCustomizationNicMapping  -verbose:$false | Set-OSCustomizationNicMapping -IpMode UseDhcp -verbose:$false | Out-Null	# for dhcp
	}
	elseif ($spBuildData.IPAddressInfo -as [Net.IPAddress])
	{
		# PortGroup,VLAN,NetworkID,NetworkGw,NetworkMask,Dns1,Dns2,ClusterShort
		Get-OSCustomizationSpec $spec -verbose:$false  | new-OSCustomizationNicMapping -verbose:$false| `
		Set-OSCustomizationNicMapping -IpMode UseStaticIP `
									  -IpAddress $spBuildData.IpAddressInfo -SubnetMask $vmNetworkSettings.NetworkMask `
									  -DefaultGateway $vmNetworkSettings.NetworkGw -verbose:$false
		
		# –DnsServer $($vmNetworkSettings.Dns1)), $($vmNetworkSettings.Dns2)		
		# Get-OSCustomizationSpec testByAVA | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIP -IpAddress 192.168.100.1 -SubnetMask 255.255.255.0 -DefaultGateway 192.168.100.254
	}
	else
	{
		Write-Error "ERROR: IPAddressInfo from sharepoint is not valid"
		exit
	}
	
	# Once...a long time ago we were able to 'write-output $spec' and that contained every thing we needed
	# I think when static IP addresses are used it screws up the write-output.
	# Anyway, not a big deal, we just re-get the spec right after we finish this function
	
}

function get-vmClusterChoice
{
	<#
		.SYNOPSIS
			This function connects to the VmRatios (http://dcappprd158/netops/Lists/VmRatios/AllItems.aspx) 
			list and figures out how busy the clusters are based on vCPU allocation.  The least busy cluster that fits the 
			environment (Prd, Integrated, stand-alone, etc)	will be selected

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$spVmRatioList,
		[parameter(Mandatory = $true)]
		[string]$vmClusterPartial,
		[parameter(Mandatory = $true)]
		[string]$uri,
		#[parameter(Mandatory = $true)]
		#[string]$ignoreClusterRatio,
		[parameter(Mandatory = $true)]
		[string]$failureDomain
	)
	
	# create the web service
	write-verbose "LOG: Accessing list $spVmRatioList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	# Get rows
	$listRows = get-spListItems -listname $spVmRatioList -service $service | ? { $_.ows_Title -like "*$vmClusterPartial*" }
	write-verbose "LOG: got $(($listRows | measure-object).count) list rows for $spVmRatioList for cluster *$vmClusterPartial*"
	
	$clusterCustomObj = @()  # Custom object to store the cluster ratio information
	
	foreach ($row in $listRows)
	{
		$obj = @()
		$obj = "" | Select-Object ClusterName, cpuCoreVirtualToPhyRatio, CapacityStatus
		$obj.ClusterName = $row.ows_Title
		Write-Verbose "Found a cluster entry $($row.ows_Title) `($($row.ows_cpuCoreVirtualToPhyRatio)`) in VmRatios list"
		$obj.cpuCoreVirtualToPhyRatio = $row.ows_cpuCoreVirtualToPhyRatio
		$obj.CapacityStatus = $row.ows_CapacityStatus
		$clusterCustomObj += $obj
	}
	
	# Select the cluster with the lowest ows_cpuCoreVirtualToPhyRatio that is not full
	# It's possible that the entry can be empty but we'll test for that below
	foreach ($cluster in ($clusterCustomObj | Sort-Object -Descending -Property cpuCoreVirtualToPhyRatio) )
	{
		$clusterObj = Get-Cluster -name $cluster.ClusterName -verbose:$false
		
		try
		{
			$tagClusterFailureDomain = (Get-TagAssignment -Entity $clusterobj -Category FailureDomain -verbose:$false).tag.name
		}
		catch
		{
			Write-Error "Cluster $($clusterObj.name) does not have a FailureDomain Tag.  Assign a tag using the web client"
		}
		
		Write-Verbose "Cluster $($clusterObj.name) uses FailureDomain Tag: $tagClusterFailureDomain, VM uses $failureDomain"
		
		
		if (	($tagClusterFailureDomain -eq $failureDomain) -or ($tagClusterFailureDomain -eq 'AUTO-SELECT') -or ($failureDomain -eq 'AUTO-SELECT')	)
		{
			Write-Verbose "Cluster $($clusterObj.name) matches FailureDomain Tag: $tagClusterFailureDomain, check cluster capacity for this VM"
			
			if ($cluster.CapacityStatus -ne 'Full')
			{
				Write-Verbose "Use Cluster $($clusterObj.name) `($($cluster.cpuCoreVirtualToPhyRatio)`) for VM deployment"
				Write-Output $($clusterObj.name)
				return # return out of the function, we found a cluster, no need to query any others.
			}
			else
			{
				Write-Verbose "Cluster $($clusterObj.name) is full per vmRatios list, will look for another cluster"
			}
		}
	}
	
	# If we get this far that means that no cluster matched the FailureDomain or the cluster is full
	Write-Error "Clusters $vmClusterPartial-* may be `"full`" or didn't match Failure Domain `($failureDomain`), check via VmRatios list and vCenter tags."
	
	
}

<#
	.SYNOPSIS
		A brief description of the set-VMTag function.

	.DESCRIPTION
		A detailed description of the set-VMTag function.

	.PARAMETER  ParameterA
		The description of a the ParameterA parameter.

	.PARAMETER  ParameterB
		The description of a the ParameterB parameter.

	.EXAMPLE
		PS C:\> set-VMTag -ParameterA 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the set-VMTag function with named parameters.

	.EXAMPLE
		PS C:\> set-VMTag 'One value' 32
		'This is the output'
		This example shows how to call the set-VMTag function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
function set-VmTag {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]
		$vm,
		[Parameter(Mandatory = $true)]
		[system.string]
		$failuredomain
		
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
		}
		catch {
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function get-NetbiosDomainNameForComputerandAccessGroups
{
	<#
		.SYNOPSIS
			This function get's the netbios domain name of the domain where
			the computers and access groups live
			

		.DESRIPTION
		
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$adOuMapDefinition,
		[parameter(Mandatory = $true)]
		$spBuildData
	)
	
	$adOuMapKeyFields = "$($spBuildData.NetworkSecurityZone)|$($spBuildData.DataCenterLocation)|$($spBuildData.ITEnvironment)"
	$adMaps = $adOuMapDefinition.$adOuMapKeyFields
	$adApplicationBaseDn = $adMaps.split("|")[0]	# Get DN, don't need
	$stickyAdDomainName = $adMaps.split("|")[1]	# Get domain name of this object
	$NetbiosDomainNameForComputerandAccessGroups = (get-addomain -identity $stickyAdDomainName).NetBiosName
	
	Write-Output $NetbiosDomainNameForComputerandAccessGroups
}

function get-adDomainControllerNameForComputerandAccessGroupObjects
{
	<#
		.SYNOPSIS
			This function gets the single domain controller we should use for creating
			computer object Ou, computer object, nad Access group.  Do not use for Role group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$adOuMapDefinition,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$adDefaultAdSiteForObjectCreation
	)
	
	$adOuMapKeyFields = "$($spBuildData.NetworkSecurityZone)|$($spBuildData.DataCenterLocation)|$($spBuildData.ITEnvironment)"
	$adMaps = $adOuMapDefinition.$adOuMapKeyFields
	$adApplicationBaseDn = $adMaps.split("|")[0]	# Get DN, don't need
	$stickyAdDomainName = $adMaps.split("|")[1]	# Get domain name of this object
	$adDefaultSite = $adDefaultAdSiteForObjectCreation.$stickyAdDomainName	# Get the default AD site based on the domain name
	Write-Verbose "Default AD site for Computer and Resource Access object creation will be: $adDefaultSite"
	$adDomainControllerFqdnName = get-stickyAdDomainController -stickyAdDomainName $stickyAdDomainName -adDefaultSite $adDefaultSite
	Write-Verbose "Using domain controller $adDomainControllerFqdnName for Computer and Resource Access object creation "
	
	Write-Output $adDomainControllerFqdnName
}

function get-stickyAdDomainController
{
	<#
		.SYNOPSIS
			This function will figure out what site the computer is going to 
			be deployed into and will use the InterSiteTopologyGenerator domain 
			controller to create all the OU's, compter objects, Acess and Role
			group objects and OUs.  We do this because sites have a 15 minute delay 
			in object replication so it's best to have all of the objects that the 
			computer needs created in the site that the computer will be deployed to.
			Note that (for example) if you deploy a computer to Los Angeles you will not see
			the resulting groups and objects in your ADUC when connected to domain controllers
			in the Reston site for up to 15 minutes (when inter-site replication runs).

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$stickyAdDomainName,
		[parameter(Mandatory = $true)]
		[string]$adDefaultSite
	)
	
	# Get a domain controller in this domain in this site.
	$adDomainControllerObj = Get-ADDomainController -SiteName $adDefaultSite -discover -domainname $stickyAdDomainName
	$adDomainControllerFqdnName = $adDomainControllerObj.Hostname[0]
	
	Write-Output $adDomainControllerFqdnName
	
}

function get-adDomainControllerNameForRoleGroupObjects
{
	<#
		.SYNOPSIS
			This function gets the single domain controller we should use for creating
			Role groups.  Do not use for computer or Access groups

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$adGroupOuDefinition,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$adDefaultAdSiteForObjectCreation
	)
	
	$adOuMapKeyFields = "Role|$($spBuildData.NetworkSecurityZone)"
	$adMaps = $adGroupOuDefinition.$adOuMapKeyFields
	$stickyAdDomainName = $adMaps.split("|")[1]	# Get domain name of this object
	$adDefaultSite = $adDefaultAdSiteForObjectCreation.$stickyAdDomainName	# Get the default AD site based on the domain name
	Write-Verbose "Default AD site for Role group object creation will be: $adDefaultSite"
	$adDomainControllerFqdnName = get-stickyAdDomainController -stickyAdDomainName $stickyAdDomainName -adDefaultSite $adDefaultSite
	Write-Verbose "Using domain controller $adDomainControllerFqdnName for Role group object creation "
	
	Write-Output $adDomainControllerFqdnName
}

function get-adDomainControllerNameForGpoObjects
{
	<#
		.SYNOPSIS
			This function gets the single domain controller we should use for creating
			Group policy Objects.  Do not use for computer or Access groups or role groups

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$adGpoTemplateNameDefinition,
		[parameter(Mandatory = $true)]
		[hashtable]$adDefaultAdSiteForObjectCreation
	)
	
	$gpoClassifierFields = $spBuildData.NetworkSecurityZone
	$gpoMaps = $adGpoTemplateNameDefinition.$gpoClassifierFields
	$stickyAdDomainName = $gpoMaps.split("|")[1]	# Get domain name of this object
	$adDefaultSite = $adDefaultAdSiteForObjectCreation.$stickyAdDomainName	# Get the default AD site based on the domain name
	Write-Verbose "Default AD site for GPO object creation will be: $adDefaultSite"
	$adDomainControllerFqdnName = get-stickyAdDomainController -stickyAdDomainName $stickyAdDomainName -adDefaultSite $adDefaultSite
	Write-Verbose "Using domain controller $adDomainControllerFqdnName for GPO object creation "
	
	Write-Output $adDomainControllerFqdnName
}

function get-adGpoTemplateAndDomainName
{
	<#
		.SYNOPSIS
			This function gets the GPO template name

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$adGpoTemplateNameDefinition
	)
	
	$gpoClassifierFields = $spBuildData.NetworkSecurityZone
	$gpoMaps = $adGpoTemplateNameDefinition.$gpoClassifierFields
	$adGpoTemplateName = $gpoMaps.split("|")[0]	# template name
	$adGpoDomainName = $gpoMaps.split("|")[1]	# domain name
	Write-Verbose "Using GPO template: $adGpoTemplateName in domain $adGpoDomainName"
	
	Write-Output $adGpoTemplateName, $adGpoDomainName
}

function new-adComputerOu
{
	<#
		.SYNOPSIS
			This function will create an application specific OU for the computer account

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$adOuMapDefinition,
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory = $true)]
		[string]$adSqlServerOu
	)
	
	$adComputerOuClassifierFields = "$($spBuildData.NetworkSecurityZone)|$($spBuildData.DataCenterLocation)|$($spBuildData.ITEnvironment)"
	$adMaps = $adOuMapDefinition.$adComputerOuClassifierFields	# The parent DN of the new application OU
	$adApplicationBaseDn = $adMaps.split("|")[0]
	$applicationName = $spBuildData.ApplicationName
	$serverRole = $spBuildData.ServerRole
	$cotsWithSql = $spBuildData.CotsWithSql	# 0 (no cots) or 1 (cots)
	
	#
	# Define name of OU
	#
	if (($serverRole -eq 'SQL') -and ($cotsWithSql -eq 0))
	{
		Write-Verbose "This is a standard SQL server"
		$adApplicationDn = "OU=$adSqlServerOu,$adApplicationBaseDn"
		
	}
	elseif ((($serverRole -eq 'App') -or ($serverRole -eq 'Web')) -and ($cotsWithSql -eq 0))
	{
		# A normal Web or App server
		$adApplicationDn = "OU=$applicationName,$adApplicationBaseDn"
		
	}
	elseif ((($serverRole -eq 'App') -or ($serverRole -eq 'Web') -or ($serverRole -eq 'SQL')) -and ($cotsWithSql -eq 1))
	{
		# A COTS application hosting both SQL and the App
		#	 on the same box. The computer should live uner
		#	SQL-SERVERS\[APPLICATION NAME] so both the SQL and App admins
		#	can be given administrator permissions via GPO
		Write-Verbose "This is a App/Web/SQL server with COTS"
		# reset the baseDn so when we create the application OU inside the 'SQL-SERVERS'
		#	Prevents us from having to put more logic into the New-QADObject call below
		$adApplicationBaseDn = "OU=$adSqlServerOu,$adApplicationBaseDn"
		$adApplicationDn = "OU=$applicationName,$adApplicationBaseDn"
		
	}
	else
	{
		# Normal application OU
		Write-Verbose "This is a normal app/web server server"
		$adApplicationDn = "OU=$applicationName,$adApplicationBaseDn"
	}
	
	#
	# Create OU
	#
	# Note: The quest AD cmdlets don't support -erroraction stop so I can't use Try/Catch
	
	#
	# Create OU
	#
	if (! (get-qadobject $adApplicationDn -Service $domainControllerNameForComputerandAccessGroupObjects))
	{
		# create OU because it does not exist
		Write-verbose "OU $adApplicationDn does not exist, we will create it ($domainControllerNameForComputerandAccessGroupObjects)"
		$adApplicationBaseDnResult = New-QADObject -Type OrganizationalUnit -ParentContainer $adApplicationBaseDn -Name $applicationName -Description "Servers supporting $applicationName" -Service $domainControllerNameForComputerandAccessGroupObjects
	}
	else
	{
		write-verbose "OU $adApplicationDn already exists, will not re-create ($domainControllerNameForComputerandAccessGroupObjects)"
	}
	
	# return the DN of the OU where the computer will be created and the FQDN of the domain name
	Write-Output $adApplicationDn
	
	
}

function new-adComputer
{
	<#
		.SYNOPSIS
			This function creates the computer object in AD

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[string]$deleteComputer,
		[parameter(Mandatory = $true)]
		[string]$adApplicationDn,
		[parameter(Mandatory = $true)]
		[string]$adComputerAndAccessGrpDomainName,
		[parameter(Mandatory = $true)]
		[string]$adComputerTemplate,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects
	)
	
	
	#
	# Create Computer
	#
	
	$itProjectDescription = $spBuildData.ITProjectDescription # Friendly app name
	$adComputerDn = "CN=$newComputerName,$adApplicationDn"	# full DN to new computer object
	$adDomainandComputer = "$adComputerAndAccessGrpDomainName\$newComputerName"
	$adSamAccountName = $newComputerName + '$'	# Add $ to end of samAccountName because quest cmdlets don't do this for you
	$adSamAccountName = $adSamAccountName.toupper()
	
	
	if (! (Get-QADComputer -Name $newComputerName -Service $domainControllerNameForComputerandAccessGroupObjects))
	{
		# AD computer object does not exist, so create it
		Write-Verbose "Creating computer object for $newComputerName ($domainControllerNameForComputerandAccessGroupObjects)"
		Write-Verbose "ParentContainer: $adApplicationDn"
		$adComputerCreateResult = New-QADComputer -ParentContainer $adApplicationDn -Description "Runs $itProjectDescription" -Location $spBuildData.DataCenterLocation -Name $newComputerName -SamAccountName $adSamAccountName -ObjectAttributes @{ 'OperatingSystem' = $spBuildData.OperatingSystem; } -Service $domainControllerNameForComputerandAccessGroupObjects -ErrorAction Stop
		
	}
	else
	{
		# AD computer object already exists but we need to figure out if we are going to:
		# A) delete and recreate computer if you specified -deletecomputer on the cmd line
		# B) exit the script with error - the default option
		if ($deleteComputer -eq 'True')
		{
			# if we said -deleteComputer on CMDline we will delete and recreate
			Write-Verbose "Removing existing computer account $newComputerName in $adComputerAndAccessGrpDomainName ($domainControllerNameForComputerandAccessGroupObjects)"
			get-qadcomputer -name $newComputerName -Service $domainControllerNameForComputerandAccessGroupObjects | remove-qadobject -Service $domainControllerNameForComputerandAccessGroupObjects -Confirm:$false -Force -ErrorAction Stop # this cmdlet does not return any results... so can't capture
			
			Write-Verbose "Re-creating computer object for $newComputerName ($domainControllerNameForComputerandAccessGroupObjects)"
			Write-Verbose "Computer OU DN: $adApplicationDn"
			$adComputerCreateResult = New-QADComputer -ParentContainer $adApplicationDn -Description "Runs $itProjectDescription" -Location $spBuildData.DataCenterLocation -Name $newComputerName -SamAccountName $adSamAccountName -ObjectAttributes @{ 'OperatingSystem' = $spBuildData.OperatingSystem; } -Service $domainControllerNameForComputerandAccessGroupObjects -ErrorAction Stop
			
		}
		else
		{
			# This is the default, exit the script if a duplicate computer account is found
			$computerGetResult = get-qadcomputer -name $newComputerName -IncludedProperties LastLogonTimeStamp -Service $domainControllerNameForComputerandAccessGroupObjects
			$c_os = $computerGetResult.OperatingSystem
			$c_dn = $computerGetResult.dn
			try { $c_llts = $computerGetResult.LastLogonTimeStamp }
			catch { $c_llts = "DoesNotExist" }
			Write-Verbose "INFO: existing OS $c_os"
			Write-Verbose "INFO: existing DN $c_dn"
			write-verbose "INFO: existing LastLogonTimeStamp (passwd change): $c_llts"
			Write-Error "AD computer account $newComputerName already exists, use -deletecomputer to override"
			exit
		}
	}
	
	write-output $adComputerCreateResult
}

function get-localAdmins
{
	<#
		.SYNOPSIS
			This function takes input from sharepoint LocalAdmins field and cleans up the users\groups

		.DESRIPTION
			Looks like this before cleanup
			20;#US\gdecker;#16;#US\aventura;#18;#US\sdukas;#1;#US\a_bconrad;#17;#US\oalexis;#6;#US\netops-dc;#50;#US\domain admins

	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData
	)
	
	$serverRole = $spBuildData.ServerRole	# Web/App/SQL
	$localAdmins = @()	# will hold cleaned up admin/group names
	
	if (! ($spBuildData.LocalAdmins))
	{
		# No admins found in LocalAdmins
		
		# We will not set $localAdmins here because later in the main body we are check to see if it's null or not.
		#Write-Verbose "No local admins defined, for non SQL+COTS we'll be creating empty role groups for future use"
	}
	else
	{
		# Admins found in LocalAdmins
		
		#initial split, result will have a blank line in the beginning
		$localAdminsDirty = $spBuildData.LocalAdmins -split ('\d+;#')
		$localAdminsDirty = $localAdminsDirty | ? { $_ -ne "" } # get rid of any blank lines
		foreach ($dirtyAdmin in $localAdminsDirty)
		{
			$cleanAdmin = $dirtyAdmin -replace (';#', '')	# remove the trailing ;# and put clean entry into localadmins
			$localAdmins += $cleanAdmin	# add user or group to localAdmins list
		}
	}
	
	Write-Output $localAdmins	# clean array of local admins
	
}

function GET-VerticalName
{
	<#
		.SYNOPSIS
			This function will look at NetworkSecurityZone and figure out the 
			name of the vertical based on a rule in the verticalNameDefinition hash

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[hashtable]$verticalNameDefinition,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		$spBuildData
	)
	
	
	$NetworkSecurityZone = $spBuildData.NetworkSecurityZone
	
	# Custom Object
	$obj = New-Object PSObject
	$obj | Add-Member Noteproperty -Name VerticalCompany -value $verticalNameDefinition.item($NetworkSecurityZone).COMPANY
	$obj | Add-Member Noteproperty -Name VerticalAbbr -value $verticalNameDefinition.item($NetworkSecurityZone).abbr
	
	Write-Output $obj
	
	
}

function new-adRoleGroup
{
	<#
		.SYNOPSIS
			This function creates role groups

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$adGroupOuDefinition,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForRoleGroupObjects,
		[parameter(Mandatory = $true)]
		[string]$verticalAbbr
	)
	
	$itEnvironment = $spBuildData.ITEnvironment	# DEV/TST/PRD/BAT
	# build the hash Key
	$adRoleGroupClassifierFields = "Role|$($spBuildData.NetworkSecurityZone)"
	# Based on Key get the value of what base DN the role groups should be in
	$adMaps = $adGroupOuDefinition.$adRoleGroupClassifierFields	# looks like: OU=ROLE,OU=UNRESTRICTED,OU=_GROUPS,DC=US,DC=COSTAR,DC=LOCAL|US.COSTAR.LOCAL
	$adRoleGroupBaseDn = $adMaps.split("|")[0]	# Dn like OU=ROLE,OU=UNRESTRICTED,OU=_GROUPS,DC=US,DC=COSTAR,DC=LOCAL
	$adRoleGroupDomain = $admaps.split("|")[1].split(".")[0] # Netbios domain name like US  (assuming netbios name matches DNS domain name like US=US)
		
	# Define the role group name
	#$adRoleGroupName = "$($spBuildData.ApplicationName)_Server_Admins_$itEnvironment"
	$adRoleGroupName = "$($spBuildData.ApplicationName)_Server_Admins_$itEnvironment" + "_$verticalAbbr"
	Write-Verbose "adRoleGroupName: $adRoleGroupName"
	# Create the full DN with rolegroup name & base dn
	$adRoleGroupNameDn = "CN=$adRoleGroupName,$adRoleGroupBaseDn"
	Write-Verbose "adRoleGroupNameDn: $adRoleGroupNameDn"
	
	Write-Verbose "Checking for $adRoleGroupName"
	try
	{
		get-adgroup -identity $adRoleGroupName -server $domainControllerNameForRoleGroupObjects | Out-Null
		[system.Boolean]$AdRoleGroupExits = $true
	}
	catch
	{
		[system.Boolean]$AdRoleGroupExits = $false
	}
	
	#if (! (get-adgroup -identity $adRoleGroupName -server $domainControllerNameForRoleGroupObjects))
	if ($AdRoleGroupExits -eq $false)
	# Don't use DN for search because some groups are in non standard locations.
	# For example EnterpriseCRM_Server_Admins_DEV_CS is in RESTRICTED instead of the default UNRESTRICTED.
	# get-adgroup does not like [domain]\[groupname] rather it prefers just [groupname] for -identity.
	# as long as we are also using -server the lack of domain name seems to work it self out and
	# I think this will scale using multiple domains for Role groups because the domain controller at -server is checking
	# its local domain database for [groupname]
	{
		# Create role group
		Write-Verbose "Creating role group $adRoleGroupName ($adRoleGroupNameDn), ($domainControllerNameForRoleGroupObjects)"
		New-ADGroup -PATH $adRoleGroupBaseDn -name $adRoleGroupName -Description "Admin access to the servers running $($spBuildData.ApplicationName)" -SamAccountName $adRoleGroupName -GroupScope Global -GroupCategory Security -server $domainControllerNameForRoleGroupObjects
		$adRoleGroupCreateResult = $(get-adgroup $adRoleGroupName -server $domainControllerNameForRoleGroupObjects)
		
	}
	else
	{
		$adRoleGroupCreateResult = $(get-adgroup $adRoleGroupName -server $domainControllerNameForRoleGroupObjects)
		write-verbose "Role group $adRoleGroupName ($($adRoleGroupCreateResult.DistinguishedName)) already exists, not creating ($domainControllerNameForRoleGroupObjects)"
		
	}
	
	Write-Output $adRoleGroupCreateResult
}

function add-usersToRoleGroup
{
	<#
		.SYNOPSIS
			This function will add the local admins to the role group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$adRoleGroupCreateResult,
		[parameter(Mandatory = $true)]
		[array]$localAdmins,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForRoleGroupObjects
	)
	
	# Add each user or role group from the sharepoint LocalAdmins field
	foreach ($admin in $localAdmins)
	{
		
		# Check for valid user
		if ((Get-QADObject -identity $admin -Service $domainControllerNameForRoleGroupObjects).Type -eq 'User')
		{
			# If user is not already a member of role group add him
			if (! (Get-QADUser $admin -MemberOf $adRoleGroupCreateResult.Name -Service $domainControllerNameForRoleGroupObjects))
			{
				Write-Verbose "Adding user $admin to $($adRoleGroupCreateResult.Name) ($domainControllerNameForRoleGroupObjects)"
				$userAddResult = Set-QADGroup $adRoleGroupCreateResult.Name -Service $domainControllerNameForRoleGroupObjects -Member @{ Append = @($admin) }
			}
			else
			{
				Write-Verbose "User $admin is already a member of $($adRoleGroupCreateResult.Name), skipping... ($domainControllerNameForRoleGroupObjects)"
			}
		}
		else
		{
			# Not a 'user', this is some sort of AD group, we'll use another function that will add to the access group
		}
	}
}

function new-adAccessGroup
{
	<#
		.SYNOPSIS
			This function creates access group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$adGroupOuDefinition,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory = $true)]
		[string]$NetbiosDomainNameForComputerandAccessGroups,
		[parameter(Mandatory = $true)]
		[string]$verticalAbbr
	)
	
	$adAccessGroupClassifierFields = "Access|$($spBuildData.NetworkSecurityZone)"
	$adMaps = $adGroupOuDefinition.$adAccessGroupClassifierFields
	$adAccessGroupBaseDn = $adMaps.split("|")[0]
	$adAccessGroupName = "RGA_$($spBuildData.ApplicationName)_Administrators_$($spBuildData.ITEnvironment)_$NetbiosDomainNameForComputerandAccessGroups" + "_$verticalAbbr"
	$adAccessGroupNameDn = "CN=$adAccessGroupName,$adAccessGroupBaseDn"
	
	try
	{
		Get-ADGroup -identity $adAccessGroupName -server $domainControllerNameForComputerandAccessGroupObjects | Out-Null
		[boolean]$createNewAccessGroup = $false
	}
	catch
	{
		[boolean]$createNewAccessGroup = $true
	}
	
	if ($createNewAccessGroup -eq $true)
	{
		Write-Verbose "Access Group does not exist, creating: $adAccessGroupNameDn ($domainControllerNameForComputerandAccessGroupObjects)"
		$newADGroupResult = New-ADGroup -Description "Admin access to the servers running $($spBuildData.ApplicationName)" -Name $adAccessGroupName -GroupCategory security -GroupScope DomainLocal -Path $adAccessGroupBaseDn -Server $domainControllerNameForComputerandAccessGroupObjects
		$adAccessGroupCreateResult = get-adgroup $adAccessGroupNameDn -server $domainControllerNameForComputerandAccessGroupObjects	
	}
	else
	{
		write-verbose "Access group $adAccessGroupName $adAccessGroupNameDn already exists, not creating ($domainControllerNameForComputerandAccessGroupObjects)"
		$adAccessGroupCreateResult = get-adgroup $adAccessGroupNameDn -server $domainControllerNameForComputerandAccessGroupObjects
	}
	
	Write-Output $adAccessGroupCreateResult
}

function add-adNewRoleToAccessGroup
{
	<#
		.SYNOPSIS
			This function adds the role group to the access group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$adAccessGroupCreateResult,
		[parameter(Mandatory = $true)]
		$adRoleGroupCreateResult,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForRoleGroupObjects
	)
	
	# Get the netbios domain name of the domain where this Role groups lives
	$adRoleGroupCreateResult.sid.value -match '(?<domainSid>S-\d-\d-\d+-\d+-\d+-\d+)(-\d+)' | Out-Null
	$AdRoleGroupDomainSid = $matches.domainsid
	$adRoleGroupDomain = (Get-ADDomain -identity $AdRoleGroupDomainSid -server $domainControllerNameForRoleGroupObjects).NetBIOSName
	
	# If the DN of the role group we just tried to create is in this Access group
	# 	that means the role group is already in the access group, so skip the addition and go to 'else'
	# This will happen when adding a second server to an existing applicationName (it's ok)
	$adAccessGroupMembers = @(Get-adgroupMember $adAccessGroupCreateResult.DistinguishedName -server $domainControllerNameForComputerandAccessGroupObjects | % { $_.distinguishedName }) # populate array with the DNs
	if (! ($adAccessGroupMembers -contains $adRoleGroupCreateResult.DistinguishedName))
	{
		# we did not find our role group in our access group
		# Append (not replace) membership into our access group
		#Write-Verbose "Adding $adRoleGroupDomain\$($adRoleGroupCreateResult.name) ( $($adRoleGroupCreateResult.dn) ) to $($adAccessGroupCreateResult.name) ($($adAccessGroupCreateResult.DistinguishedName) ) ($domainControllerNameForComputerandAccessGroupObjects)"
		Write-Verbose "Adding $adRoleGroupDomain\$($adRoleGroupCreateResult.name) ( $($adRoleGroupCreateResult.DistinguishedName) ) to $($adAccessGroupCreateResult.name) ($($adAccessGroupCreateResult.DistinguishedName) ) ($domainControllerNameForComputerandAccessGroupObjects)"
		$roleGroup = Get-ADGroup -identity $adRoleGroupCreateResult.name -server $domainControllerNameForRoleGroupObjects
		$accessGroup = Get-ADGroup -identity $adAccessGroupCreateResult.name -server $domainControllerNameForComputerandAccessGroupObjects
		Add-ADGroupMember $accessGroup -member $roleGroup -server $domainControllerNameForComputerandAccessGroupObjects
		
	}
	else
	{
		Write-Verbose "Role group $adRoleGroupDomain\$($adRoleGroupCreateResult.name) is already a member of $($adAccessGroupCreateResult.name) ($domainControllerNameForComputerandAccessGroupObjects)"
	}
	
}

function add-adExistingRoleToAccessGroup
{
	<#
		.SYNOPSIS
			This function adds any 'role' groups you specified in Sharepoint into the Access group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$adAccessGroupCreateResult,
		[parameter(Mandatory = $true)]
		[array]$localAdmins,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForRoleGroupObjects
	)
	
	
	# Get the netbios domain name of the domain where this groups lives
	$adAccessGroupCreateResult.sid.value -match '(?<domainSid>S-\d-\d-\d+-\d+-\d+-\d+)(-\d+)' | Out-Null
	$AccessGroupdomainSid = $matches.domainsid
	$adAccessGroupDomain = (Get-ADDomain -identity $AccessGroupdomainSid -Server $domainControllerNameForComputerandAccessGroupObjects).NetBIOSName
	
	# Itterate through the users/groups submitted via the LocalAdmins sharepoint field
	foreach ($admin in $localAdmins)
	{
		
		# clean up the account/group name that we got from SharePoint to remove the [domain]\ at the beginnin
		$admin = $admin.split("\")[1]
		
		$adObject = get-adobject -filter { SamAccountName -eq $admin } -Server $domainControllerNameForRoleGroupObjects
		Write-Verbose "Adding this localadmin object: $admin"
		
		#
		# If $admin is a AD role group of type security, universal or global add it to the RGA Access group
		#
		if ($adObject.ObjectClass -eq 'Group')
		{
			$adGroup = Get-ADGroup -identity $adobject.DistinguishedName -Server $domainControllerNameForRoleGroupObjects
			
			$adGroup.sid -match '(?<domainSid>S-\d-\d-\d+-\d+-\d+-\d+)(-\d+)' | Out-Null
			$RoleGroupdomainSid = $matches.domainsid
			$adRoleGroupDomain = (Get-ADDomain -identity $RoleGroupdomainSid -Server $domainControllerNameForRoleGroupObjects).NetBIOSName
			
			$adGroupCategory = $adGroup.GroupCategory	# like Security
			$adGroupScope = $adGroup.GroupScope	# like Universal
			$adGroupObjectClass = $adGroup.ObjectClass # like Group
			$adGroupName = $adGroup.Name
			$adGroupGuid = $adGroup.ObjectGUID
		
			if (($AdGroupCategory -eq 'Security') -and (($adGroupScope -eq 'Universal') -or ($adGroupScope -eq 'Global')))
			{
				# We have ensured that this group is a Global/Universal Security group (but not a user), will add to access group
				
				$adRoleGroupCreateResult = $adGroup
				
				# If the DN of the role group we want to add is in this Access group
				# 	that means the role group is already in the access group, so skip the addition and go to 'else'
				# This will happen when adding a second server to an existing application (it's ok)
				$adAccessGroupMembers = @(Get-adgroupMember $adAccessGroupCreateResult.DistinguishedName -server $domainControllerNameForComputerandAccessGroupObjects | % { $_.distinguishedName }) # populate array with the DNs
				
				if (! ($adAccessGroupMembers -contains $adRoleGroupCreateResult.distinguishedName))
				{
					# Based on the query results the role group is not yet a member of the access group
					# Append (not replace) membership into our access group
					
					Write-Verbose "Adding $adRoleGroupDomain\$($adRoleGroupCreateResult.name) ( $($adRoleGroupCreateResult.distinguishedName) ) to $($adAccessGroupCreateResult.name) ($($adAccessGroupCreateResult.distinguishedName) ) ($domainControllerNameForComputerandAccessGroupObjects)"
					$roleGroup = Get-ADGroup -identity $adRoleGroupCreateResult.name -Server $domainControllerNameForRoleGroupObjects
					$accessGroup = Get-ADGroup -identity $adAccessGroupCreateResult.name -server $domainControllerNameForComputerandAccessGroupObjects
					Add-ADGroupMember $accessGroup -member $roleGroup -server $domainControllerNameForComputerandAccessGroupObjects
					
				}
				else
				{
					Write-Verbose "Role group $adRoleGroupDomain\$($adRoleGroupCreateResult.name) is already a member of $($adAccessGroupCreateResult.name) ($domainControllerNameForComputerandAccessGroupObjects)"
					$adAddExistingRoletoAccessGroupResult = get-ADGroup $adAccessGroupCreateResult.name -Server $domainControllerNameForComputerandAccessGroupObjects
				}
			}
		}
		#
		#	$admin was not a group, rather a user
		#
		else
		{
			# If not a group ($adObject.Type is  'user')
			$adAddExistingRoletoAccessGroupResult = 'NoExistingRoleGroupsDefinedInLocalAdmins'
		}
	}

}

function new-rgaGpo
{
	<#
		.SYNOPSIS
			This function will copy our source template GPO to our permament GPO

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$adGpoTemplateName,
		[parameter(Mandatory = $true)]
		[string]$adGpoDomainName,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$adAccessGroupCreateResult,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForGpoObjects,
		[parameter(Mandatory = $true)]
		[string]$NetbiosDomainNameForComputerandAccessGroups
	)
	
	# Build the destination GPO name
	$gpoNameFinal = "srv.RGA_$($spBuildData.ApplicationName)_Administrators_$($spBuildData.ITEnvironment)_$NetbiosDomainNameForComputerandAccessGroups"
	
	# We must create a shell GPO with basic GPP restricted group info intact
	#
	# We then back up, modify the groups.xml file and them import
	# back into the newly created GPO.
	#
	# Note that the PowerShell Group Policy CMDLets do not
	#	support creating rescricted groups in GPP
	#
	
	# Ensure the template GPO exists
	try
	{
		$gpoTemplate = Get-GPO -Name $adGpoTemplateName -Domain $adGpoDomainName -Server $domainControllerNameForGpoObjects -ErrorAction Stop
	}
	catch
	{
		Write-Error "Unable to find $adGpoTemplateName in $adGpoDomainName $error[0]"
		exit
	}
	
	# Check to see if this GPO already exists (maybe because this is the second server you are adding to this GPO)
	# If it does exist, don't do anything.  If it does not exist, copy the template to a new gpo
	
	$gpoCopyReport = "" | Select-Object DisplayName, Id, SkipProcessing
	
	if ($gpo = Get-GPO -Name $gpoNameFinal -Domain $adGpoDomainName -Server $domainControllerNameForGpoObjects -ErrorAction SilentlyContinue)
	{
		# Gpo already exists
		$gpoCopyReport.DisplayName = $gpo.DisplayName
		$gpoCopyReport.Id = $gpo.Id
		$gpoCopyReport.SkipProcessing = 'Yes'
		Write-Verbose "GPO $($gpo.DisplayName) already exists, skipping the copy from template $adGpoTemplateName"
		Write-Output $gpoCopyReport
		return # Gpo already exists, tell the caller to skip processing
	}
	else
	{
		try
		{
			Write-Verbose "Creating new GPO ($gpoNameFinal) in $adGpoDomainName ($domainControllerNameForGpoObjects)"
			$gpo = copy-gpo -SourceName $adGpoTemplateName -SourceDomain $adGpoDomainName -TargetName $gpoNameFinal -TargetDomain $adGpoDomainName -CopyAcl -SourceDomainController $domainControllerNameForGpoObjects -TargetDomainController $domainControllerNameForGpoObjects
			$gpoCopyReport.DisplayName = $gpo.DisplayName
			$gpoCopyReport.Id = $gpo.Id
			$gpoCopyReport.SkipProcessing = 'No'
		}
		catch
		{
			Write-Error "Unable to copy $adGpoTemplateName to $gpoNameFinal $error[0]"
			exit
		}
	}
	
	Write-Output $gpoCopyReport
	
}

function backup-rgaGpo
{
	<#
		.SYNOPSIS
			This function will backup our GPO so we can edit with xml

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$gpoCopyReport,
		[parameter(Mandatory = $true)]
		$adAccessGroupCreateResult,
		[parameter(Mandatory = $true)]
		$domainControllerNameForGpoObjects,
		[parameter(Mandatory = $true)]
		$adGpoDomainName
	)
	
	# You can't manage GPP restricted groups with powershell CMDLets.  To overcome this
	# limitation we will do the following:
	#	A) Backup the GPO we just made
	#	B) Edit groups.xml
	#	C) import the backed up GPO into the new production gpo
	
	# backup this GPO, edit the GptTmpl.inf file (adding users), import back into same GPO
	$gpoBackupDirBase = $env:TEMP
	$gpoBackupGuid = [system.guid]::newguid().tostring()
	$gpoBackupDir = "$gpoBackupDirBase\$gpoBackupGuid"
	
	mkdir $gpoBackupDir | Out-Null	# Create the backup dir
	
	# Backup the GPO
	try
	{
		Write-Verbose "Backing up GPO $($gpoCopyReport.DisplayName) to $gpoBackupDir ($domainControllerNameForGpoObjects)"
		$backupGpoReport = Backup-GPO -name $gpoCopyReport.DisplayName -Domain $adGpoDomainName -Path $gpoBackupDir -Server $domainControllerNameForGpoObjects -ErrorAction Stop
		$backupGpoReport | Add-Member -Name gpoBackupDir -Value $gpoBackupDir -MemberType NoteProperty
		
	}
	catch
	{
		write-error "Error backing up gpo $($gpoCopyReport.DisplayName) to $gpoBackupDir ($domainControllerNameForGpoObjects)"
		exit
	}
	
	write-output $backupGpoReport # if ID is set the caller can consider this a valid key for initiating the groups.xml edit
}

function import-rgaGpo
{
	<#
		.SYNOPSIS
			This function will backup our GPO so we can edit with xml

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$adAccessGroupCreateResult,
		[parameter(Mandatory = $true)]
		$backupGpoReport,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForGpoObjects,
		[parameter(Mandatory = $true)]
		[string]$adGpoDomainName
	)
	
	# Import the groups.xml file into XML so we can manipulate the 'Member' objects
	# The template gpo should have only 1 entry for the local administrators
	# We change that 1 entry to our RGA_ group here:
	$pathToGroupsXml = (gci -Recurse $backupGpoReport.gpoBackupDir | ? { $_.Name -eq 'groups.xml' }).FullName
	[xml]$xml = Get-Content $pathToGroupsXml
	
	$xml.Groups.Group.Properties.members.member.name = $adAccessGroupCreateResult.Name
	$xml.Groups.Group.Properties.members.member.action = 'ADD'
	$xml.Groups.Group.Properties.members.member.sid = $adAccessGroupCreateResult.Sid.value
	$xml.Save($pathToGroupsXml)
	
	# clone add a new row if needed
	#$clone = $xml.Groups.Group.Properties.members.member.clone()
	#$clone.name = 'us\boo'
	#$xml.documentelement.Group.Properties.members.AppendChild($clone)
	#$xml.Groups.Group.Properties.members.member
	
	# Import the GPO that was modified locally into the AD version
	try
	{
		Write-Verbose "Importing $($backupGpoReport.Displayname), $($backupGpoReport.id) ($domainControllerNameForGpoObjects)"
		$importGpoResult = Import-GPO -BackupId $backupGpoReport.id -Path $backupGpoReport.gpoBackupDir -Domain $adGpoDomainName -Server $domainControllerNameForGpoObjects -Confirm:$false -TargetGuid $backupGpoReport.GpoId -ErrorAction Stop
	}
	catch
	{
		Write-Error "Unable to import $($backupGpoReport.DisplayName) to $adGpoDomainName ($domainControllerNameForGpoObjects)"
		exit
	}
	
	# current directory
	$pwdOriginal = $pwd.path
	# remove our backup dir
	cd $env:TEMP
	rmdir -Path $backupGpoReport.gpoBackupDir -recurse -Force
	
	Write-Output $importGpoResult
	
	cd $pwdOriginal # back to original pwd
}

function new-adGpoLink
{
	<#
		.SYNOPSIS
			This function will link our GPO to the OU where the computer account resides

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$adApplicationDn,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForGpoObjects,
		[parameter(Mandatory = $true)]
		[string] $adGpoDomainName,
		[parameter(Mandatory = $true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory = $true)]
		$gpoCopyReport
	)
	
	$gpoName = $gpoCopyReport.DisplayName
	$gpoGuid = $gpoCopyReport.id.guid
	
	# Using AD cmdlets there does not seem to be a reliable way to list the gplinks when the GPO lives in the parent domain and the link is in a child domain
	#  This quest cmdlet will do until it's stops working
	#  6/2/2015 Check out Get-SDMGPLink some day (https://sdmsoftware.com/group-policy-management-products/freeware-group-policy-tools-utilities/)
	$adCheckIfGpoAlreadyLinkedResults = Get-QADObject -identity $adApplicationDn -type OrganizationalUnit -includeallproperties -Service $domainControllerNameForComputerandAccessGroupObjects
	if ($adCheckIfGpoAlreadyLinkedResults.gPLink)
	{
		# A GPO is already linked to this OU.  It's probably because you are adding
		#	additional servers into this OU and a previous deployment already linked this GPO.
		# But we need to check to make sure the GPO we see that is already linked is the GPO that we are expecting to use for RGA
		# The gpLink GUID should match the GUID of our $gpoName, this tells us for sure the proper GPO is linked.
		
		# Going extra mile to make sure that the GPO linked to $adApplicationDn is actually the one we want linked
		# Not totally bulletproof when multiple GPOs are already linked but as long as our $gpoName
		# is linked that is fine.
		$gPLink = $adCheckIfGpoAlreadyLinkedResults.gPLink
		#$gPLink -like "*$gpoGuid*" | Out-Null	# Match the GPO GUID so we can write the derived GPO name to verbose output
		$gpoNameDerived = (Get-GPO -Guid $gpoGuid -Domain $adGpoDomainName -Server $domainControllerNameForGpoObjects).DisplayName
		if ($gpoNameDerived -eq $gpoName)
		{
			$msg = "GPO $gpoNameDerived already linked to $adApplicationDn (OK) ($domainControllerNameForGpoObjects)"
			Write-Verbose $msg
			return
		}
		else
		{
			Write-Error "The GPO ($gpoNameDerived) linked to $adApplicationDn is not what we were expecting ($gpoName) ($domainControllerNameForGpoObjects)"
			exit
		}
	}
	else
	{
		# GPO is not linked yet, try to link it
		try
		{
			$gpoLinkResult = New-GPLink -Target $adApplicationDn -Name $gpoName -Domain $adGpoDomainName -Server $domainControllerNameForGpoObjects -ErrorAction Stop
			Write-Verbose "Linked GPO $gpoName to $adApplicationDn ($domainControllerNameForGpoObjects)"
		}
		catch
		{
			Write-Error "Failed to link GPO $gpoName to $adApplicationDn ($domainControllerNameForGpoObjects)"
			exit
		}
	}
	Write-Output $gpoLinkResult
}

function get-MicrosoftProductKey
{
	<#
		.SYNOPSIS
			This function determins which KMS key we should use based on the OS selected
		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[hashtable]$clientKmsKeyMapping
	)
	
	$spOs = $spBuildData.OperatingSystem
	$osKey = $clientKmsKeyMapping.$spOs
	
	Write-Output $osKey
	
}

function get-timeZoneMapping
{
	<#
		.SYNOPSIS
			Based on sharepoint input gets the proper time zone.

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$timeZoneMapping
	)
	
	$dctrLoc = $spBuildData.DataCenterLocation
	$timeZone = $timeZoneMapping.$dctrLoc
	
	Write-Output $timeZone
	
}

function get-networksettings
{
	<#
		.SYNOPSIS
			This function provides the logic to set the proper vm portgroup

		.DESRIPTION
			Based on DataCenterCountry, DataCenterLocation, ITEnvironment,ITSubEnvironment
			and ServerRole coming in from Sharepoint we'll figure out 
			which portgroup the VM should be on
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$networkDefinition,
		[parameter(Mandatory = $true)]
		$r	# sharepoint list object
	)
	
	# We build a string from the sharepoint fields and we'll use
	# that string to find the proper network settings in the $networkDefinition hash.
	# $networkDefinition is the business rule that tells us where to place the VM
	
	# our format: DataCenterCountry|DataCenterLocation|ITEnvironment|ITSubEnvironment|ServerRole
	# This defines the characteristics of the server request from sharepoint
	$inventoryClassifierFields = "$($r.NetworkSecurityZone)|$($r.DataCenterCountry)|$($r.DataCenterLocation)|$($r.ITEnvironment)|$($r.ITSubEnvironment)|$($r.ServerRoleAppended)"
	
	# using the hash key.value we will spit out the proper network information
	$networkValues = $networkDefinition.$inventoryClassifierFields
	
	# Split into an object for easy reference and pass back to the caller
	# Value fields: NetworkSecurityZone(0),portgroup(1),vlan#(2),networkID(3),gateway(4),networkMask(5),dns1(6),dns2(7),vmcluster(8)
	$eachNetworkValue = $networkValues.split("|")
	$obj = "" | Select-Object NetworkSecurityZone, PortGroup, VLAN, NetworkID, NetworkGw, NetworkMask, Dns1, Dns2, ClusterShort
	$obj.NetworkSecurityZone = $r.NetworkSecurityZone
	$obj.PortGroup = $eachNetworkValue[0]
	$obj.VLAN = $eachNetworkValue[1]
	$obj.NetworkID = $eachNetworkValue[2]
	$obj.NetworkGw = $eachNetworkValue[3]
	$obj.NetworkMask = $eachNetworkValue[4]
	$obj.Dns1 = $eachNetworkValue[5]
	$obj.Dns2 = $eachNetworkValue[6]
	$obj.ClusterShort = $eachNetworkValue[7]	# Partial name of vmware cluster
	
	Write-Output $obj
}

function test-ValidDriveLetters
{
	<#
		.SYNOPSIS
			Make sure the user did not request two E: drives (for example)

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$diskTable
	)
	
	$diskTableTotalRows = ($diskTable | measure-object).count
	$diskTableUniqeRows = ($disktable | select -Unique -Property DiskLetter | measure-object).count
	if ($diskTableTotalRows -ne $diskTableUniqeRows)
	{
		Write-Error "The sharepoint list row has duplicate drive letters"
		exit
	}
}

function test-noSpacesInApplicationName
{
	<#
		.SYNOPSIS
			This function ensures we do not have spaces in our ApplicationName

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		$spBuildData
	)
	
	$applicationName = $spBuildData.ApplicationName
	if ($applicationName -match '\s+')
	{
		Write-Error "Spaces not allowed in ApplicationName.  Use `"Pascal Case`" for naming style.  Ex: MyApp ; ProducSuiteSearch ; ProductDataServices"
		exit
	}
}

function test-isThisATemplate
{
	<#
		.SYNOPSIS
			This function figures out if the source VM is a 'template' or a 'VM'

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$vmTemplateObj
	)
	
	# Note: $vmTemplateObj can be either a template or a VM, so we have to check to
	#	see which type we have
	try
	{
		$isTemplate = ($vmTemplateObj).ExtensionData.summary.config.template
		# this property should resolve to 'true', but not $true but it's still a System.Boolean
	}
	catch
	{
		# vms don't have ExtensionData.summary.config.template so that is how we tell this is a live VM
		[system.boolean]$isTemplate = $false
	}
	
	
	Write-Output $isTemplate
	
}

function test-vmHostHasIsolatedPortgroupForClone
{
	<#
		.SYNOPSIS
			This function ensures that the host has an isolated portgroup that can be used for hot clones

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$vmHostForDeployment,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$vmPortGroupForClones,
		[parameter(Mandatory = $True, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$vmSwitchForClones
	)
	
	$vmPortGroupForClones = 'template-pg'
	$vmSwitchForClones = 'template-internal-only'
	$vmhost = get-vmhost -Name $vmHostForDeployment -Verbose:$false
	if ($($vmhost | Get-VirtualSwitch -Name $vmSwitchForClones | Get-VirtualPortGroup | ? { $_.Name -eq $vmPortGroupForClones }))
	{
		Write-Verbose "Verified host $vmHostForDeployment has an isloated portgroup ($vmPortGroupForClones) for this clone"
	}
	else
	{
		Write-Error "Host $vmHostForDeployment does not have an isloated portgroup ($vmPortGroupForClones) or does not have a vSwitch named $vmSwitchForClones for this clone"
	}
	
}

function publish-vm
{
	# clones and configures basic vm level configs
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[psObject]$vmTemplateObj,
		[parameter(Mandatory = $true)]
		[VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl]$vmfsDataStoreObj,
		[parameter(Mandatory = $true)]
		[string]$vmHostForDeployment,
		[parameter(Mandatory = $true)]
		$spec,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$DiskStorageFormatBaseDisk,
		[parameter(Mandatory = $true)]
		$DiskStorageFormatDataDisk,
		[parameter(Mandatory = $true)]
		[System.Boolean]$isTemplate,
		[parameter(Mandatory = $true)]
		[System.String]$companyVertical
	)
	
	
	# As a standard, costar Vms are lowercase
	$newComputerName = $newComputerName.tolower()
	Write-verbose "`t-Using VM template $($vmTemplateObj.name)"
	Write-verbose "`t-Using datastore $($vmfsDatastoreObj.name)"
	Write-verbose "`t-Using $DiskStorageFormatBaseDisk base disk storage format"
	if (! $spBuildData.ServerRole -eq 'SQL')
	{
		Write-verbose "`t-Using $DiskStorageFormatDataDisk data disk storage format"
		
	}
	Write-verbose "`t-Using VMName $newComputerName"
	Write-verbose "`t-Using VMhost $vmHostForDeployment"
	
	$dataCenterName = (Get-Datacenter -verbose:$false -VMHost $vmHostForDeployment).name	
	if (! $spBuildData.ServerRole -eq 'SQL')
	{
		$vmFolderPathString = "$datacentername/VERTICALS/$Companyvertical/SqlServers"
	}
	else
	{
		$vmFolderPathString = "$datacentername/VERTICALS/$Companyvertical"
	}	
	
	Write-Verbose "Looking for this folder: $vmFolderPathString"
	$folderImpl = get-folderbypath -Path "$vmFolderPathString"
	Write-Verbose "Will use this folder for placing VM: $vmFolderPathString"
	
	$OperatingSystem = $spBuildData.operatingsystem
	
	try
	{
		if ($isTemplate -eq $true)
		{
			Write-Verbose "Deploying VM $newComputerName from template..."
			if ($OperatingSystem -eq '_emptyshell_for_testing')
			{
				# deploy the VM without a spec, only used for quickly testing the script end-to-end
				# without waiting for a full OS deployment.  Also allows us to keep testing and not use
				# up thin space on the EMC LUns
				#$vmDeployResult = New-VM -Name $newComputerName -template $vmTemplateObj -Datastore $dataStoreName `
				$vmDeployResult = New-VM -Name $newComputerName -template $vmTemplateObj -Datastore $vmfsDatastoreObj `
										 -VMHost $vmHostForDeployment   `
										 -DiskStorageFormat $DiskStorageFormatBaseDisk -Description "$($spBuildData.ITProjectDescription);$($spBuildData.ITProjectManager)" -Location $folderImpl -ErrorAction Stop -Verbose:$false
			}
			else
			{
				# Standard deployment
				#$vmDeployResult = New-VM -Name $newComputerName -template $vmTemplateObj -Datastore $dataStoreName `
				$vmDeployResult = New-VM -Name $newComputerName -template $vmTemplateObj -Datastore $vmfsDatastoreObj `
										 -VMHost $vmHostForDeployment -OSCustomizationSpec $spec  `
										 -DiskStorageFormat $DiskStorageFormatBaseDisk -Description "$($spBuildData.ITProjectDescription);$($spBuildData.ITProjectManager)" -Location $folderImpl -ErrorAction Stop
			}
		}
		else
		{
			# clone from existing VM
			Write-Verbose "Deploying VM $newComputerName from existing VM $($vmTemplateObj.name)..."
			#$vmDeployResult = New-VM -Name $newComputerName -VM $($vmTemplateObj.name) -Datastore $dataStoreName `
			$vmDeployResult = New-VM -Name $newComputerName -VM $($vmTemplateObj.name) -Datastore $vmfsDatastoreObj `
									 -VMHost $vmHostForDeployment -OSCustomizationSpec $spec  `
									 -DiskStorageFormat $DiskStorageFormatBaseDisk -Description "$($spBuildData.ITProjectDescription);$($spBuildData.ITProjectManager)" -location $folderImpl -ErrorAction Stop
		}
	}
	catch
	{
		Write-Verbose "$($error[0])"
		Write-error "Unable to deploy VM $newComputerName on host $vmHostForDeployment"
		exit
	}
}

function set-VmSettings
{
	<#
		.SYNOPSIS
			This function sets memory and cpu and network on the VM

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$vmHostObj,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		$vmPortGroupSelection,
		[parameter(Mandatory = $true)]
		[system.boolean]$isTemplate,
		[parameter(Mandatory = $true)]
		[string]$vmPortGroupForClones
	)
	
	
	# set RAM, CPU
	$vmRamMB = ([int]$spBuildData.RamGB) * 1024
	$vmNumCpu = ([int]$spBuildData.CpuCnt)
	# Note we set the DRS automation level to Manual so that a subsequent vMotion during customization does not break the customization
	$confSetVmObj = Set-VM -VM $newComputerName -MemoryMB $vmRamMB -NumCpu $vmNumCpu -Confirm:$false -DrsAutomationLevel Manual -ErrorAction Stop -Verbose:$false
	
	try
	{
		# if it's a template (vs a hot-clone), it's OK to connect the vNIC
		if ($isTemplate -eq $true)
		{
			
			if ($vmhostObj | get-vdswitch -Verbose:$false)
			{
				Write-Verbose "$($vmhostObj.name) has one or more vDS"
				$portGroupObj = $vmhostObj | Get-VDSwitch -Verbose:$false | Get-VDPortGroup -Verbose:$false | ? { $_.name -eq $vmPortGroupSelection }
				$vSwitchName = $portGroupObj.VDSwitch
			}
			else
			{
				Write-Verbose "$($vmhostObj.name) has vSS and does not have a vDS"
				$portGroupObj = $vmhostObj | Get-VirtualSwitch | Get-VirtualPortGroup -Standard -Verbose:$false | ? { $_.name -eq $vmPortGroupSelection }
				$vSwitchName = $portGroupObj.VirtualSwitch
			}
			
			Write-Verbose "Selected portgroup $($portGroupObj.name) on $vSwitchName"
			$confNicObj = Get-VM -name $newComputerName -Verbose:$false | Get-NetworkAdapter -Verbose:$false | Set-NetworkAdapter -PortGroup $portGroupObj -Confirm:$false -ErrorAction Stop -Verbose:$false
			
			
		}
		else
		{
			# if it's not a template (it is a clone), it is not safe to connect the vNIC because the new VM will come up with the same
			#	name as the original.  If static IP, it will come up with a duplicate IP address
			# Plain old cloning via vCenter starts this new VM with the nic disconnected but enables the vNic while the VM OS
			#	is running and you can see that the new VM has the exact same name as the old VM.  If the new vm has
			#	network connectivity it can talk to domain controllers and regirster with DNS and that is bad news for the source VM
			
			Write-Verbose "This is a clone, using $vmPortGroupSelection for portgroup"
			$vmPortGroupSelection = $vmPortGroupForClones # set portgroup to the clone portgroup
			$confNicObj = Get-VM -name $newComputerName -Verbose:$false | Get-NetworkAdapter -Verbose:$false | Set-NetworkAdapter -NetworkName (Get-VirtualPortGroup -VMHost $vmHostForDeployment -Name $vmPortGroupSelection -Verbose:$false) -Confirm:$false -ErrorAction Stop -Verbose:$false
		}
	}
	catch
	{
		Write-Error "Unable to set VM network portgroup to $vmPortGroupSelection"
	}
	
}

function new-vmHardDiskTable
{
	<#
		.SYNOPSIS
			This function will build a table object of valid virtual disks.
			Table to be used in add-vmDisk()

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$diskConfigMaxMin,
		[parameter(Mandatory = $true)]
		$spRequestAllFieldsObj
	)
	
	
	$diskTable = @()
	
	$listRows = $spRequestAllFieldsObj # shorter name for all the sharepoint fields
	
	# Determines how many disks to add, change global $diskConfigMaxMin
	#	to add support for more disks
	$startingDiskNum = $diskConfigMaxMin.startingDiskNum
	$endingDiskNum = $diskConfigMaxMin.endingDiskNum
	
	# We don't know exactly how many disks were specified
	#	via Sharepoint so we itterate through all disks through $endingDiskNum
	# Also note that if a field is empty in sharepoint it is not listed in $listRows, we use this
	#	for loop to figure everything out
	for ($i = $startingDiskNum; $i -le $endingDiskNum; $i++)
	{
		
		# Build strings that we'll use to match against the Sharepoint row
		# remember, we don't know how many disks were specified so we use
		# this strings to see if we can match a sharepoint disk in the try{} section
		$diskLetterField = "HardDisk$($i)DriveLetter"	# looks like HardDisk2DriveLetter
		$diskSizeGbField = "HardDisk$($i)SizeGB"	# looks like HardDisk2SizeGB
		$diskLabelField = "HardDisk$($i)Label"	# looks like HardDisk2Label
		
		# If diskLabel exists, capture, otherwise set a default
		try
		{
			$diskLabel = $listRows."ows_$($diskLabelField)"
		}
		catch
		{
			$diskLabel = "Data Disk $i"
		}
		
		# Initialize the object
		$obj = "" | select-object HardDiskNum, DiskLetter, DiskLabel, DiskSizeKB
		
		# Using try {} we check to see if $listRows.HardDisk[x]SizeGB exists.
		#	 if it does, we add the disk letter to the report
		try
		{
			$diskLetter = $listRows."ows_$($diskLetterField)" # try{} will fail if this does not exist
			$diskSizeGb = $listRows."ows_$($diskSizeGbField)"	# try{} will fail if this does not exist
			# If neither of the 2 properties failed we safely say we want to add this
			#	disk because it has 1) drive letter 2) size specified
			write-verbose "Adding disk to table: $diskLetter/$diskSizeGb/$diskLabel"
			$obj.HardDiskNum = "Hard Disk $i"
			$obj.DiskLetter = $diskLetter
			$obj.DiskLabel = $diskLabel
			
			$obj.DiskSizeKB = [int]$diskSizeGb * 1MB
			
			$diskTable += $obj
		}
		catch
		{
			#			Write-Verbose "Does not exist: $diskLetterField"
			#			$obj.HardDiskNum = "Hard Disk $i"
			#			$obj.DiskLetter = 'NoDiskRequested'
			#			$obj.DiskSizeKB = 0
			#			$obj.DiskLabel = 'NoDiskRequested'
			#			$diskTable += $obj
		}
		
	}
	
	Write-Output $diskTable
}

function set-vmConfigSpec
{
	<#
		.SYNOPSIS
			This function allows us to interact with .config.extraconfig.guestinfo

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[string]$key,
		[parameter(Mandatory = $true)]
		[string]$value
	)
	
	$vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
	$extra = New-Object VMware.Vim.optionvalue
	$extra.Key = $key
	$extra.Value = $value
	$vmConfigSpec.extraconfig += $extra
	$vm = Get-View -ViewType VirtualMachine -Filter @{ "Name" = $newComputerName } -Verbose:$false
	$vm.ReconfigVM($vmConfigSpec)
}

function get-vmConfigSpec
{
	<#
		.SYNOPSIS
			This function allows us to interact with .config.extraconfig.guestinfo

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[string]$key
	)
	
	$vm = Get-View -ViewType VirtualMachine -Filter @{ "Name" = $newComputerName } -Verbose:$false
	try
	{
		$value = ($vm.config.extraconfig | ? { $_.key -eq $key }).value
	}
	catch
	{
		$value = 'KeyNotFound'
	}
	Write-Output $value
}

function add-vmDisk
{
	<#
		.SYNOPSIS
			This function adds the virtual disks to the VM

		.DESRIPTION
			add-vmDisk uses the .config.extraconfig.guestinfo properties on the VM to pass messages
		back and forth between this script and the disk provisioning script running in the VM.  The
		vmtools on the VM allows the modification of .config.extraconfig.guestinfo so that makes for 
		a nice two-way message passing system between the two scripts.
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		$diskTable,
		[parameter(Mandatory = $true)]
		$DiskStorageFormatDataDisk,
		[parameter(Mandatory = $true)]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[boolean]$isWindows
	)
	
	#$vm = Get-View -ViewType VirtualMachine -Filter @{"Name" = $newComputerName} -Verbose:$false
	$diskAddResultTable = @()
	
	# Figure out if these disks will be thick or thin.  We base this on the strategy that
	#	web and app server data disks (e:, f:, etc) will be thin.  SQL server disks will
	#	always be Thick
	$serverRole = $spBuildData.ServerRole # Web/app/SQL
	if ($serverRole -eq 'SQL')
	{
		$DiskStorageFormatDataDisk = 'Thick'
		$DiskClusterSize = '64K'
	}
	else
	{
		# Take the defaults from the top of this script
		$DiskClusterSize = '4K'	# normal volume default is 4KB http://support.microsoft.com/kb/140365
	}
	
	# Keep count of how many disks we will add.  When we have added all of our
	# 	disks we will tell the guest to 'Finished' and then break out of the foreach loop below
	# If we have additional disks to add we will tell the guest to SendGuestToReadyState
	$numDisks = ($diskTable | measure-object).count
	$counter = 0
	foreach ($diskObj in $diskTable)
	{
		
		# Check to see if disks should be set to IndependentPersistent
		if ($spBuildData.ServerRole -eq 'SQL')
		{
			# If this is a SQL server, check the counter
			if ($counter -eq 0)
			{
				# only the first disk (E:) on a SQL server should be persistent
				# Does not support multi-instance VMs with multiple sysvols...
				$diskPersistence = 'Persistent'
			}
			else
			{
				# all other disks on SQL server will be IP
				$diskPersistence = 'IndependentPersistent'
			}
		}
		else
		{
			# Not a SQL server so set all disks to Persistent
			$diskPersistence = 'Persistent'
		}
		
		$obj = "" | Select-Object HardDiskNum, DiskLetter, DiskLabel, DiskSizeKB, Id, FileName
		
		if ($isWindows -eq $true)
		{
			# The guest should be running the DiskFormat.ps1 script and setting guestinfo.DiskAdditionStatus = GuestReadyForDisks
			# 	waiting for us to add a disk.
			while ((get-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskAdditionStatus') -ne 'GuestReadyForDisks')
			{
				Write-Verbose "Waiting for $newComputerName to fire up disk formatting script $(get-date)"
				sleep 10
			}
		}
		
		# Add the disk and sleep to allow guest OS to recognize the disk
		$vm = Get-VM -Name $newComputerName -Verbose:$false
		$newHardDiskResult = New-HardDisk -vm $vm -CapacityKB $diskObj.DiskSizeKB -StorageFormat $DiskStorageFormatDataDisk -Persistence $diskPersistence -confirm:$false -Verbose:$false
		sleep 5
		
		if ($isWindows -eq $true)
		{
			# Tell guest OS what the drive letter is (DiskMetadata) and tell it we presented a disk (DiskAdditionStatus)
			set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskLetter' -value $diskObj.DiskLetter
			set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskLabel' -value $diskObj.diskLabel
			set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.diskClusterSize' -value $diskClusterSize
			set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskAdditionStatus' -value 'DiskPresentedForFormat'
			Write-Verbose "Presenting disk $($diskObj.DiskLetter) to $newComputerName"
			
			# Wait until the guest posts back that it formatted the disk (by posting back 'Formatted')
			while ((get-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskAdditionStatus') -ne 'Formatted')
			{
				Write-Verbose "Waiting for $newComputerName to format $($diskObj.DiskLetter)"
				sleep 5
			}
			Write-Verbose "$newComputerName finished formatting $($diskObj.DiskLetter)"
		}
		
		# add to results table
		$obj.HardDiskNum = $diskObj.HardDiskNum
		$obj.DiskLetter = $diskObj.DiskLetter
		$obj.DiskSizeKB = $diskObj.DiskSizeKB
		$obj.Id = $newHardDiskResult.Id
		$obj.FileName = $newHardDiskResult.FileName
		$obj.DiskLabel = $diskObj.DiskLabel
		
		$diskAddResultTable += $obj #add to report
		
		$numDisks--
		if ($numDisks -eq 0)
		{
			# We have no more disks to format. Tell the guest and then  bust out of this loop
			if ($isWindows -eq $true)
			{
				set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskAdditionStatus' -value 'Finished'
			}
			continue
		}
		else
		{
			# There are still disks to format, tell guest to call publish-disks
			# we will be waiting for the guest to tell us it's ready when we get back to
			# the top of this foreach loop.
			if ($isWindows -eq $true)
			{
				set-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.DiskAdditionStatus' -value 'SendGuestToReadyState'
			}
		}
		$counter++
	}
	
	Write-Output $diskAddResultTable
}

function enable-vm
{
	<#
		.SYNOPSIS
			This function turns on the VM

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[string]$vmhost	# VM host to start VM on.  Will be same as VM host used for clone
	)
	
	$actionStartVMObj = Start-VM -VM $newComputerName -Confirm:$false -ErrorAction Stop
	
	#
	# Monitor for customization to complete
	# http://blogs.vmware.com/vipowershell/2012/08/waiting-for-os-customization-to-complete.html
	#
	
}

function wait-sysprepComplete
{
	<#
		.SYNOPSIS
			This function will run after guest customization has been verified with wait-VmCustomizationToComplete()

		.DESRIPTION
			After we have run RunOnce.cmd on the guest the last thing that happens is that
			c:\it\sysprep_RunOnce\TellvCenterSysprepIsComplete.ps1 is run which sets the 
			config.extraconfig.guestInfo value SysprepStatus to 'complete'
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$newComputerName,
		[parameter(Mandatory = $true)]
		[int] $waitDelay,
		[parameter(Mandatory = $true)]
		[int] $stableAfterNumSeconds
	)
	
	while ((get-vmConfigSpec -newComputerName $newComputerName -key 'guestinfo.SysprepStatus') -ne 'complete')
	{
		Write-Verbose "Waiting for $newComputerName to finish RunOnce activities $(get-date)"
		sleep $waitDelay
	}
	
	Write-verbose "Will sleep for $stableAfterNumSeconds seconds to ensure OS stability"
	sleep $stableAfterNumSeconds
}

function send-monitoringRequest
{
	<#
		.SYNOPSIS
			This function sends out a monitoring request to the helpdesk
			
		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		#[parameter(Mandatory=$true)]
		#[ValidateNotNullOrEmpty()]
		#[string]$smtpFrom='MonitoringRequest@costar.com',
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpTo,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpServer
	)
	
	$sR = "" | Select-Object HostName, Requester, MonitoringRequirement, ApplicationName, Description, ITProject, ITEnvironment, ITSubEnvironment, DataCenterLocation, OperatingSystem, NetworkSecurityZone, ServerDeployer
	$sR.Description = $spBuildData.title
	$sR.Requester = $spBuildData.ServerRequester
	$sR.ApplicationName = $spBuildData.ApplicationName
	$sR.Hostname = $spBuildData.hostname
	$sR.ITProject = $spBuildData.ITProject
	$sR.ITEnvironment = $spBuildData.ITEnvironment
	$sR.ITSubEnvironment = $spBuildData.ITSubEnvironment
	$sR.DataCenterLocation = $spBuildData.DataCenterLocation
	$sR.OperatingSystem = $spBuildData.OperatingSystem
	$sR.MonitoringRequirement = $spBuildData.NetIQMonitoringRequirements
	$sR.ServerDeployer = $env:USERNAME
	$sR.NetworkSecurityZone = $spBuildData.NetworkSecurityZone
	
	$smtpBody = ""
	$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
	$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
	$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
	$style = $style + "TD{border: 1px solid black; padding: 5px; }"
	$style = $style + "</style>"
	$smtpBody = $sR | ConvertTo-Html -Head $style -As LIST
	
	Write-Verbose "Sending monitoring request to the Helpdesk for new server $($sR.Hostname)"
	send-Mail -smtpTo $smtpTo -smtpSubject "Netops: Monitoring request for new server `($($sR.Hostname)`)" -smtpBody $smtpBody -smtpServer $smtpServer -smtpFrom $sR.Requester
	
}

function send-BackupRequest
{
	<#
		.SYNOPSIS
			This function sends out a third-party backup request (like BAckup exec) to the helpdesk
			
		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpTo,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpServer
	)
	
	$sR = "" | Select-Object HostName, Requester, BackupRequirements, ApplicationName, Description, ITProject, ITEnvironment, ITSubEnvironment, DataCenterLocation, OperatingSystem, NetworkSecurityZone, ServerDeployer
	$sR.Description = $spBuildData.title
	$sR.Requester = $spBuildData.ServerRequester
	$sR.ApplicationName = $spBuildData.ApplicationName
	$sR.Hostname = $spBuildData.hostname
	$sR.ITProject = $spBuildData.ITProject
	$sR.ITEnvironment = $spBuildData.ITEnvironment
	$sR.ITSubEnvironment = $spBuildData.ITSubEnvironment
	$sR.DataCenterLocation = $spBuildData.DataCenterLocation
	$sR.OperatingSystem = $spBuildData.OperatingSystem
	$sR.BackupRequirements = $spBuildData.BackupRequirements
	$sR.ServerDeployer = $env:USERNAME
	$sR.NetworkSecurityZone = $spBuildData.NetworkSecurityZone
	
	$smtpBody = ""
	$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
	$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
	$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
	$style = $style + "TD{border: 1px solid black; padding: 5px; }"
	$style = $style + "</style>"
	$smtpBody = $sR | ConvertTo-Html -Head $style -As LIST
	
	Write-Verbose "Sending backup request to the Helpdesk for new server $($sR.Hostname)"
	send-Mail -smtpTo $smtpTo -smtpSubject "Netops: Third party Backup request for new server `($($sR.Hostname)`)" -smtpBody $smtpBody -smtpServer $smtpServer -smtpFrom $sR.Requester
	
}

function send-FirewallObjectRequest
{
	<#
		.SYNOPSIS
			This function sends out a request to the helpdesk asking
			for a firewall object to be created
			
		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpTo,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$smtpServer
	)
	
	
	
	
	$sR = "" | Select-Object HostName, IpAddressInfo, Requester, ApplicationName, Description, ITProject, ITEnvironment, ITSubEnvironment, DataCenterLocation, OperatingSystem, NetworkSecurityZone, ServerDeployer, FirewallCommand
	$sR.Description = $spBuildData.title
	$sR.Requester = $spBuildData.ServerRequester
	$sR.ApplicationName = $spBuildData.ApplicationName
	$sR.Hostname = $spBuildData.hostname.tolower()
	$sR.ITProject = $spBuildData.ITProject
	$sR.ITEnvironment = $spBuildData.ITEnvironment
	$sR.ITSubEnvironment = $spBuildData.ITSubEnvironment
	$sR.DataCenterLocation = $spBuildData.DataCenterLocation
	$sR.OperatingSystem = $spBuildData.OperatingSystem
	$sR.ServerDeployer = $env:USERNAME
	$sR.NetworkSecurityZone = $spBuildData.NetworkSecurityZone
	$sR.IpAddressInfo = $spBuildData.IpAddressInfo
	
	if ($sR.DataCenterLocation = 'Reston, VA') { $objectColor = "Sky Blue" }
	if ($sR.DataCenterLocation = 'Vienna, VA') { $objectColor = "Slate Blue" }
	if ($sR.DataCenterLocation = 'Los Angelas, CA (Colo)') { $objectColor = "Brown" }
	
	# Note that convert-to-html seems to not want to honor any `r`n or <br> in the here string below
	#  :: is used as a marker and then we replace those with <br>
	$firewallCommand = @"
		::
		create host_plain svr-$($sR.Hostname)::
		modify network_objects svr-$($sR.Hostname) ipaddr $($sR.IpAddressInfo)::
		modify network_objects svr-$($sR.Hostname) comments "$($sR.Description)"::
		modify network_objects svr-$($sR.Hostname) color "$objectColor"::
		update network_objects svr-$($sR.Hostname)::
		::
"@
	$sR.FirewallCommand = $firewallCommand
	
	$smtpBody = ""
	$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
	$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
	$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
	$style = $style + "TD{border: 1px solid black; padding: 5px; }"
	$style = $style + "</style>"
	$smtpBody = $sR | ConvertTo-Html -Head $style -As LIST
	
	# fix convert-to-html issues with line breaks
	$smtpBody = $smtpBody -replace ('::','<BR>')
	
	Write-Verbose "Sending firewall object request to the Helpdesk for new server $($sR.Hostname)"
	send-Mail -smtpTo $smtpTo -smtpSubject "Netops: Add new server to firewall `($($sR.Hostname)`)" -smtpBody $smtpBody -smtpServer $smtpServer -smtpFrom $sR.Requester
	
}

function get-spListAllFieldsByTitle
{
	<#
		.SYNOPSIS
			This function connects to a Sharepoint list and get info for a given Title

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$uri,
		[parameter(Mandatory = $true)]
		[string]$spList, # Sharepoint List
		[parameter(Mandatory = $true)]
		[string]$title
	)
	
	# create the web service
	# write-verbose "LOG: Accessing list $spList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	# Get rows
	try
	{
		$listRows = get-spListItems -listname $spList -service $service | ? { $_.ows_Title -eq $title }
		#write-verbose "LOG: got list row, found ID $($listRows.ows_id), Title: $($listRows.ows_title)"
	}
	catch
	{
		#Write-Verbose "No rows found for title: $title, returning `$null"
		$listRows = $null
	}
	Write-Output $listRows
}

function remove-spListFieldById
{
	<#
		.SYNOPSIS
			This function connects to a Sharepoint list and will remove a row based on ows_Id

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$uri,
		[parameter(Mandatory = $true)]
		[string]$spList, # Sharepoint List
		[parameter(Mandatory = $true)]
		[int]$id
	)
	
	# create the web service
	#write-verbose "LOG: Accessing list $spList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	# Get rows
	try
	{
		$listRows = get-spListItems -listname $spList -service $service | ? { $_.ows_id -eq $id }
		write-verbose "Deleting list row ID $($listRows.ows_id), Title: $($listRows.ows_title)"
		remove-spListItem -listName $spList -rowId $listRows.ows_id -Service $service
	}
	catch
	{
		# Write-Verbose "No rows found for ID: $Id, returning `$null"
		$listRows = $null
	}
	
}

function set-InventoryXmlFields
{
	<#
		.SYNOPSIS
			This function prepares the xml needed to insert a new record into the serverinventory list

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$spBuildData,
		[parameter(Mandatory = $false)]
		[ValidateNotNullOrEmpty()]
		[int]$totalVMStorageRequestedMB = 0
	)
	
	$r = $spBuildData	# shortuct
	$datastoreRequestedGB = [Math]::round($totalVMStorageRequestedMB/1KB, 0)
	$ramMB = [int]$r.RamGB * 1KB
	$hostName = $r.Hostname.toupper()
	
	if (($r.OperatingSystem -match '^Windows'))
	{
		$OSType = "Windows"
	}
	else
	{
		$OSType = "Linux"
	}
	
	$xmlFields = @"
				"<Field Name='Title'>$hostName</Field>" 
		    	"<Field Name='Description'>$($r.ITProjectDescription)</Field>"
				"<Field Name='HostStatus'>Active</Field>"
				"<Field Name='CanBeDecommissionedNow'>FALSE</Field>"
				"<Field Name='ITProject'>$($r.ITProject)</Field>"
				"<Field Name='ITEnvironment'>$($r.ITEnvironment)</Field>"
				"<Field Name='ITSubEnvironment'>$($r.ITSubEnvironment)</Field>"
				"<Field Name='ITProjectManager'>$($r.ITProjectManager)</Field>"
				"<Field Name='ITProjectDirector'>$($r.ITProjectDirector)</Field>"
				"<Field Name='DataCenterLocation'>$($r.DataCenterLocation)</Field>"
				"<Field Name='DataCenterCountry'>$($r.DataCenterCountry)</Field>"
				"<Field Name='ComputerType'>$($r.ComputerType)</Field>"
				"<Field Name='OSType'>$OSType</Field>"
				"<Field Name='OSCaption'>$($r.OperatingSystem)</Field>"
				"<Field Name='SanConnected'>False</Field>"
				"<Field Name='CpuCnt'>$([int]$($r.CpuCnt))</Field>"
				"<Field Name='RamMB'>$ramMB</Field>"
				"<Field Name='TotalSanSpaceGB'>$datastoreRequestedGB</Field>"
				"<Field Name='EolDate'>$($r.EolDate)</Field>"
				"<Field Name='Requester'>$($r.ServerRequester)</Field>"
				"<Field Name='ServerRole'>$($r.ServerRole)</Field>"
				"<Field Name='NetworkSecurityZone'>$($r.NetworkSecurityZone)</Field>"
				"<Field Name='MaintenanceGroup'>$($r.MaintenanceGroup)</Field>"
"@
	
	Write-Output $xmlFields
	
}

function initialize-newSpListItem
{
	<#
		.SYNOPSIS
			This function connects to a Sharepoint list and adds a new CI row

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$uri,
		[parameter(Mandatory = $true)]
		[string]$spList, # Sharepoint List
		[parameter(Mandatory = $true)]
		$xml
	)
	
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	try
	{
		Write-Verbose "Adding new CI to the Netops $spList list"
		new-spListItem -listName $spList -xmlFields $xml -service $service
		
	}
	catch
	{
		Write-Error "Unable to add new CI to the Netops $spList list"
	}
	
}

function set-ServerRequestXmlFields
{
	<#
		.SYNOPSIS
			This function createst the XML needed to flip the deployment status from Queued to Completed in the ServerRequest list

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		
	)
	$xmlFields = @"
			"<Field Name='DeploymentStatus'>Completed</Field>"
"@
	
	Write-Output $xmlFields
	
}

function initialize-updateSpListItem
{
	<#
		.SYNOPSIS
			This function connects to a Sharepoint list updates field/fields in that row

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param (
		[parameter(Mandatory = $true)]
		[int]$id,
		[parameter(Mandatory = $true)]
		[string]$uri,
		[parameter(Mandatory = $true)]
		[string]$spList, # Sharepoint List
		[parameter(Mandatory = $true)]
		$xml
	)
	
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	try
	{
		Write-Verbose "Updating obects in row $Id for list $spList"
		update-spListItem -rowID $id -xmlFields $xml -listName $spList -service $service
		
	}
	catch
	{
		#Write-Error "Unable to add new CI to the Netops $spList list"
	}
	
}

<#
.SYNOPSIS
Pings a server multiple times to ensure it's available
Version 1.00

.DESCRIPTION
Throws terminating error if pings fail

.EXAMPLE
watch-ping -computer $computer -pingAttempts $pingAttempts

#>
function Watch-ping
{
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[string]$computer,
		[parameter(Mandatory = $True, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
		[ValidateNotNullOrEmpty()]
		[int]$pingAttempts
	)
	
	BEGIN
	{
		
	}
	PROCESS
	{
		
		# we've seen false positives when pinging LA so we will loop several times instead of once
		# It's also possible this will fail if the last ping attempt is dropped.
		$cnt = 0
		do
		{
			$pingResult = get-ping -Computer $computer -pingTimeoutMs 500
			$cnt++
		}
		while ($cnt -lt $pingAttempts)
		
		
		if (($pingResult).result -eq 'Fail')
		{
			Write-Error "Unable to ping $computer for `n$pingResult"
		}
		else
		{
			Write-Verbose "Successfully pinged $computer"
		}
		
	}
	END
	{
		
	}
	
}