Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function get-adDomainControllerNameForComputerandAccessGroupObjects {
	<#
		.SYNOPSIS
			This function get's the single domain controller we should use for creating
			computer object Ou, computer object, nad Access group.  Do not use for Role group

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[hashtable]$adOuMapDefinition,
		[parameter(Mandatory=$true)]
			$spBuildData,
		[parameter(Mandatory=$true)]
		[hashtable]$adDefaultAdSiteForObjectCreation,
		[parameter(Mandatory=$true)]
		[string]$adOuMapKeyFields
		
		)
	
	#$adOuMapKeyFields = "$($spBuildData.DataCenterLocation)|$($spBuildData.ITEnvironment)"
	$adMaps = $adOuMapDefinition.$adOuMapKeyFields
	$adApplicationBaseDn = $adMaps.split("|")[0]	# Get D
	$stickyAdDomainName = $adMaps.split("|")[1]	# Get AD domain name of this object
	$adDefaultSite = $adDefaultAdSiteForObjectCreation.$stickyAdDomainName	# Get the default AD site based on the domain name
	Write-Verbose "Default AD site for Computer and Resource Access object creation will be: $adDefaultSite"
	$adDomainControllerFqdnName = get-stickyAdDomainController  -stickyAdDomainName $stickyAdDomainName -adDefaultSite $adDefaultSite
	Write-Verbose "Using domain controller $adDomainControllerFqdnName for Computer and Resource Access object creation "
	
	Write-Output $adDomainControllerFqdnName
}

function get-stickyAdDomainController {
	<#
		.SYNOPSIS
			This function will figure out what site the computer is going to 
			be deployed into and will use the InterSiteTopologyGenerator domain 
			controller to create all the OU's, compter objects, Acess and Role
			group objects and OUs.  We do this because sites have a 15 minute delay 
			in object replication so it's best to have all of the objects that the 
			computer needs created in the site that the computer will be deployed to.
			Note that (for example) if you deploy a computer to Palo Alto you will not see
			the resulting groups and objects in your ADUC when connected to domain controllers
			in the Reston site for up to 15 minutes (when inter-site replication runs).

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[string]$stickyAdDomainName,
		[parameter(Mandatory=$true)]
		[string]$adDefaultSite
		)
	
	# Get all sites in our forest (forest determined by where this script is run from)
	#$adSitesObj = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites
	# Our network Id
	#$networkId = $vmNetworkSettings.networkId
	# Match our NetworkID to a site in AD
	#$adOurSite = $adSitesObj | ? { $_.Subnets -match $networkId }
	# Get a domain controller in this domain in this site.
	$adDomainControllerObj = Get-ADDomainController -SiteName $adDefaultSite -discover -domainname $stickyAdDomainName
	$adDomainControllerFqdnName = $adDomainControllerObj.Hostname[0]
	
	Write-Output $adDomainControllerFqdnName

}

function new-adComputerOu {
	<#
		.SYNOPSIS
			This function will create an application specific OU for the computer account

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[hashtable]$adOuMapDefinition,
		[parameter(Mandatory=$true)]
		[string]$newComputerName,
		[parameter(Mandatory=$true)]
			$spBuildData,
		[parameter(Mandatory=$true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects,
		[parameter(Mandatory=$true)]
		[string]$adComputerOuClassifierFields
		)
	
	#$adComputerOuClassifierFields = "$($spBuildData.NetworkSecurityZone)|$($spBuildData.DataCenterLocation)|$($spBuildData.ITEnvironment)"
	$adMaps = $adOuMapDefinition.$adComputerOuClassifierFields	# get The parent DN of the new application OU
	$adApplicationBaseDn = $adMaps.split("|")[0]
	$applicationName = $spBuildData.ApplicationName
	$serverRole = $spBuildData.ServerRole
	$cotsWithSql = $spBuildData.CotsWithSql	# 0 (no cots) or 1 (cots)
		
	#
	# Define name of OU
	#
	if ( ($serverRole -eq 'SQL') -and ($cotsWithSql -eq 0) ) {
		Write-Verbose "This is a standard SQL server"
		$adApplicationDn = "OU=$adSqlServerOu,$adApplicationBaseDn"
		
	} elseif ( (($serverRole -eq 'App') -or ($serverRole -eq 'Web')) -and ($cotsWithSql -eq 0) ) {
		# A normal Web or App server
		$adApplicationDn = "OU=$applicationName,$adApplicationBaseDn"
	
	} elseif ( (($serverRole -eq 'App') -or ($serverRole -eq 'Web')-or ($serverRole -eq 'SQL') ) -and ($cotsWithSql -eq 1) ) {
		# A COTS application hosting both SQL and the App
		#	 on the same box. The computer should live uner
		#	SQL-SERVERS\[APPLICATION NAME] so both the SQL and App admins 
		#	can be given administrator permissions via GPO
		Write-Verbose "This is a App/Web/SQL server with COTS"
		# reset the baseDn so when we create the application OU inside the 'SQL-SERVERS'
		#	Prevents us from having to put more logic into the New-QADObject call below
		$adApplicationBaseDn =  "OU=$adSqlServerOu,$adApplicationBaseDn"	
		$adApplicationDn = "OU=$applicationName,$adApplicationBaseDn"
	
	} else {
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
	if (! (get-qadobject $adApplicationDn -Service $domainControllerNameForComputerandAccessGroupObjects) ) {
		# create OU because it does not exist
		Write-verbose "OU $adApplicationDn does not exist, we will create it ($domainControllerNameForComputerandAccessGroupObjects)"
		$adApplicationBaseDnResult = New-QADObject -Type OrganizationalUnit -ParentContainer $adApplicationBaseDn  -Name $applicationName -Description "Servers supporting $applicationName" -Service $domainControllerNameForComputerandAccessGroupObjects
	} else {
		write-verbose "OU $adApplicationDn already exists, will not re-create ($domainControllerNameForComputerandAccessGroupObjects)"
	}
	
	# return the DN of the OU where the computer will be created and the FQDN of the domain name
	Write-Output $adApplicationDn

	
}

function new-adComputer {
	<#
		.SYNOPSIS
			This function creates the computer object in AD

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[string]$newComputerName,
		[parameter(Mandatory=$true)]
			$spBuildData,
		[parameter(Mandatory=$true)]
		[string]$deleteComputer,
		[parameter(Mandatory=$true)]
		[string]$adApplicationDn,
		[parameter(Mandatory=$true)]
		[string]$adComputerAndAccessGrpDomainName,
		[parameter(Mandatory=$true)]
		[string]$adComputerTemplate,
		[parameter(Mandatory=$true)]
		[string]$domainControllerNameForComputerandAccessGroupObjects
		)
	
	#
	# Create Computer
	#
	
	$itProjectDescription = $spBuildData.ITProjectDescription # Friendly app name
	$adComputerDn = "CN=$newComputerName,$adApplicationDn"	# full DN to new computer object
	$adDomainandComputer = "$adComputerAndAccessGrpDomainName\$newComputerName"
	$adSamAccountName = $newComputerName+'$'	# Add $ to end of samAccountName because quest cmdlets don't do this for you
	$adSamAccountName = $adSamAccountName.toupper()
	
	
	if (! (Get-QADComputer -Name $newComputerName -Service $domainControllerNameForComputerandAccessGroupObjects) )	{
		# AD computer object does not exist, so create it
		Write-Verbose "Creating computer object for $newComputerName ($domainControllerNameForComputerandAccessGroupObjects)"
		$adComputerCreateResult = New-QADComputer -ParentContainer $adApplicationDn -Description "Runs $itProjectDescription" -Location $spBuildData.DataCenterLocation -Name $newComputerName -SamAccountName $adSamAccountName -ObjectAttributes @{'OperatingSystem'=$spBuildData.OperatingSystem;} -Service $domainControllerNameForComputerandAccessGroupObjects -ErrorAction Stop 
		
	} else {
		# AD computer object already exists but we need to figure out if we are going to:
		# A) delete and recreate computer if you specified -deletecomputer on the cmd line
		# B) exit the script with error - the default option
		if ($deleteComputer -eq 'True')	{
			# if we said -deleteComputer on CMDline we will delete and recreate
			Write-Verbose "Removing existing computer account $newComputerName in $adComputerAndAccessGrpDomainName ($domainControllerNameForComputerandAccessGroupObjects)"
			get-qadcomputer -name $newComputerName -Service $domainControllerNameForComputerandAccessGroupObjects | remove-qadobject -Service $domainControllerNameForComputerandAccessGroupObjects -Confirm:$false -Force -ErrorAction Stop # this cmdlet does not return any results... so can't capture
			
			# There is a nasty race condition between the time it takes to do 
			#	remove-qadobject and when we call New-QADComputer
			# So we will sleep for ...some seconds.
			#write-verbose "sleeping to avoid race condition..."
			#sleep 5
			Write-Verbose "Re-creating computer object for $newComputerName ($domainControllerNameForComputerandAccessGroupObjects)"
			#$adComputerCreateResult = New-QADComputer -ParentContainer $adApplicationDn -Description "Runs $itProjectDescription" -Location $spBuildData.DataCenterLocation -Name $newComputerName -SamAccountName $adSamAccountName -ObjectAttributes @{'OperatingSystem'=$spBuildData.OperatingSystem;} -ErrorAction Stop
			$adComputerCreateResult = New-QADComputer -ParentContainer $adApplicationDn -Description "Runs $itProjectDescription" -Location $spBuildData.DataCenterLocation -Name $newComputerName -SamAccountName $adSamAccountName -ObjectAttributes @{'OperatingSystem'=$spBuildData.OperatingSystem;} -Service $domainControllerNameForComputerandAccessGroupObjects -ErrorAction Stop
			
		} else {
			# This is the default, exit the script if a duplicate computer account is found
			$computerGetResult = get-qadcomputer -name $newComputerName -IncludedProperties LastLogonTimeStamp -Service $domainControllerNameForComputerandAccessGroupObjects
			$c_os = $computerGetResult.OperatingSystem
			$c_dn = $computerGetResult.dn
			try { $c_llts = $computerGetResult.LastLogonTimeStamp } catch { $c_llts = "DoesNotExist" }
			Write-Verbose "INFO: existing OS $c_os"
			Write-Verbose "INFO: existing DN $c_dn"
			write-verbose "INFO: existing LastLogonTimeStamp (passwd change): $c_llts"
			Write-Error "AD computer account $newComputerName already exists, use -deletecomputer to override"
			exit
		}
	}
	 
	 write-output $adComputerCreateResult
}