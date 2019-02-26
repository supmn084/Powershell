#REQUIRES -Version 2.0

#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function set-RpLoggedImageAccess {
	<#
		.SYNOPSIS
			This function will call an appsync service plan which will enable a lun for image access mode
            and mount on the mount host

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[System.Xml.XmlElement]$appsyncRecoverpointServicePlans,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$rpImageAccessMountHost,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[EMC.WinApps.Fx.Adapter.Replication.AppSync.AppSyncSystem]$appsync
		)
		
	#
	# Recoverpoint logged image access mode on the mount host
	#
	foreach ($servicePlanName in $appsyncRecoverpointServicePlans.getenumerator() )
	{
		
		$servicePlanName_RP = $servicePlanName.'#text'

		$plan = $appsync.serviceplans | ? {$_.name -eq $servicePlanName_RP }

		# ESI 3.5 does not yet suppport filesystem snapping but you can run a service plan:
		# Will run synchronusly and will wait until the plan is done running (good)
		$imageAccessMountDateStart = Get-Date
		write-host "$servicePlanName_RP : Enable image access on mount host ($rpImageAccessMountHost) $(get-date)" -ForegroundColor Green
		$servicePlanCopies = New-EmcAppSyncServicePlanCopies -ServicePlan $plan -Confirm:$false   # Does not return anything (stupid)
		$imageAccessMountDateFinish = Get-Date
		write-host "$servicePlanName_RP : It took $([math]::Round( ($imageAccessMountDateFinish - $imageAccessMountDateStart).TotalMinutes, 0)) minutes to refresh image access on $rpImageAccessMountHost" -ForegroundColor Green
	}
}

function new-FileSystemSnaps {
	<#
		.SYNOPSIS
			This function takes filesystem snaps of the image access LUNs and mount them to one or more hosts

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[System.Xml.XmlElement]$appsyncFileSystemSnapServicePlans,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[EMC.WinApps.Fx.Adapter.Replication.AppSync.AppSyncSystem]$appsync
		)
		
	foreach ($servicePlanName in $appsyncFileSystemSnapServicePlans.GetEnumerator()) {
		
		$servicePlanName_Snap = $servicePlanName.'#text'
		
		write-host "$servicePlanName_Snap : Refreshing snapshot LUNs $(get-date)" -ForegroundColor Green
		
		$plan = $appsync.serviceplans | ? {$_.name -eq $servicePlanName_Snap }
		
		$snapMountDateStart = Get-Date
		# Will run synchronusly and will wait until the plan is done running (good)
		$servicePlanCopies = New-EmcAppSyncServicePlanCopies -ServicePlan $plan -Confirm:$false   # Does not return anything (stupid)
		$snapMountDateFinish = Get-Date
		write-host "$servicePlanName_Snap : It took $([math]::Round( ($snapMountDateFinish - $snapMountDateStart).TotalMinutes, 0)) minutes to refresh the snaps on this host" -ForegroundColor Green

		write-host "ToDo: Attach SQL databases on host" -ForegroundColor Green
	}
}

function remove-ImageAccessMode {
	<#
		.SYNOPSIS
			This function will remove replica luns from image access mode and allow Recoverpoint to continue replication

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$esiRecoverPointCluster,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[System.Xml.XmlElement]$rpConsistencyGroups,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[string]$rpReplicaCopyName,
		[parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName=$False)]
		[ValidateNotNullOrEmpty()]
		[EMC.WinApps.Fx.Adapter.Replication.RecoverPointAdapter.RecoverPointReplicationSystem]$recoverpoint
		)
	
	# Connect to replication service on local ESI host
	#$esiReplicationService = Get-EmcReplicationService | ? { $_.UserFriendlyName -eq $esiRecoverPointCluster }
	$recoverpoint.refreshall()

	# Gets the list of replication clusters, which contains all of the replication sites and systems in a replication service
	$rpCluster = Get-EmcReplicationServiceCluster -ReplicationService $recoverpoint

	
	
	

	foreach ($cg in $rpConsistencyGroups.getenumerator() )	{ 

        $cgName = $cg.'#text'

		# Retrieves consistency groups that are used to protect LUNs
		$cGroup = Get-EmcConsistencyGroup -ReplicationServiceCluster $rpCluster | ? { $_.name -eq $cgName }

		# Get our replica copy for our CG
		$replicaCopy = Get-EmcReplicaCopy -ReplicationServiceCluster $rpCluster | ? { ( ($_.CopyName -eq $rpReplicaCopyName) -and ($_.ConsistencyGroupId -eq $cGroup.id) ) }
	
		write-host "Disable Image access mode on $cgName $($replicaCopy.CopyName)" -ForegroundColor Green
		
		$DisableEmcReplicaCopyImageAccessResult = Disable-EmcReplicaCopyImageAccess -copy $replicaCopy -confirm:$false

	}

}
