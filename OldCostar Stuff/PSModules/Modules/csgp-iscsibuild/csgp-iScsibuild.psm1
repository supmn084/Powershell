#REQUIRES -Version 2.0

Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

function get-spListIscsiHostsAllFields	{
	# Connect to the sharepoint list and dump out all info for each row
 	[CmdletBinding()]
	param(
			[parameter(Mandatory=$true)]
			    [string]$uri,
		    [parameter(Mandatory=$true)]
			    [string]$sharepointList,
			[parameter(Mandatory=$true)]
			    [string]$computer
		)

	# create the web service
	write-verbose "LOG: Accessing list $sharepointList, connecting to web service at $uri"
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri

	# Get rows
	#$listRows = get-spListItems -listname $sharepointList -service $service | ? { $_.ows_ID -eq $id }
	$listRows = get-spListItems -listname $sharepointList -service $service | ? { $_.ows_title -eq $computer }
	write-verbose "LOG: got list row, found ID $($listRows.ows_id), Title: $($listRows.ows_title)"
	
	Write-Output $listRows
}	

function Initialize-IscsispData {
	<#
		.SYNOPSIS
			This function takes in the raw sharepoint row and selects important
			fields relevant to the build.  Adds to a Powershell Object that we'll use quite frequently, this object will have
			all the characteristics of the iSCSI build information

		.DESRIPTION
			
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		$spAllFieldsObj
		)

	$listRows = $spAllFieldsObj
	
	# Make sure to trim() every property or you will allow a user to create objects with spaces at the end or beginning (bad)
	
	$r = @()  # r is short for "request"
	$r = "" | Select-Object Id,Hostname,IscsiEnvironment,ItSubEnvironment, DataCenterLocation,Iscsi0EthIp,Iscsi1EthIp,Chassis,Eql0EthIp,Eql0EthMac,Eql1EthIp,Eql1EthMac
	$r.ID = $listRows.ows_id
	$r.Hostname = $listRows.ows_title.trim().tolower()
	$r.IscsiEnvironment = $listRows.ows_IscsiEnvironment
	$r.Iscsi0EthIp = $listRows.ows_Iscsi0EthIp
	$r.Iscsi1EthIp = $listRows.ows_Iscsi1EthIp
	$r.ItSubEnvironment = $listRows.ows_ItSubEnvironment
	$r.DataCenterLocation = $listRows.ows_DataCenterLocation
	$r.Chassis = $listRows.ows_chassis
	$r.Eql0EthIp = $listRows.ows_Eql0EthIp
	$r.Eql0EthMac = $listRows.ows_Eql0EthMac
	$r.Eql1EthIp = $listRows.ows_Eql1EthIp
	$r.Eql1EthMac = $listRows.ows_Eql1EthMac

	Write-Output $r
}
