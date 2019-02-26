$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2

if (!($env:PSModulePath -match "\\\\dcfile1\\systems\\scripts\\modules"))
{
	$env:PSModulePath = $env:PSModulePath + ";\\dcfile1\systems\scripts\modules"
}


if (!(Get-Module csgp-common))
{
	## Or check for the cmdlets you need
	## Load it nested, and we'll automatically remove it during clean up
	Import-Module csgp-common -ErrorAction Stop
}
if (!(Get-Module csgp-sharepointws))
{
	## Or check for the cmdlets you need
	## Load it nested, and we'll automatically remove it during clean up
	Import-Module csgp-sharepointws -ErrorAction Stop
}
if (!(Get-Module csgp-registry))
{
	## Or check for the cmdlets you need
	## Load it nested, and we'll automatically remove it during clean up
	Import-Module csgp-registry -ErrorAction 'Continue'
}


$CMDBPropTable = @{
	#'All' = 'SPObject|SPField|RegField'; #placeholder
	'RestartType' = 'ows_restarttype|RestartType|MaintenanceRestartType';
	'MaintenanceGroup' = 'ows_maintenanceGroup|MaintenanceGroup|MaintenanceGroup';
	'ITEnvironment' = 'ows_itenvironment|ITEnvironment|ITEnvironment';
	'ITProject' = 'ows_itproject|ITProject|ITProject';
	'Description' = 'ows_description|Description|Description';
}

<#
.SYNOPSIS
Get CMDB values from a computer's registry and from the Server Inventory
Version 1.00

.DESCRIPTION
Get-CMDBEntry displays the CMDB entry values "MaintenanceGroup", "MaintenanceRestartType", and "ITEnvironment" from the registry of the server(s) and from the server inventory for the server(s) specified.

It will return all CMDB values if the -CMDBEntry value of "All" is specified, or it will return only the CMDBEntry for the value specified (MaintenanceGroup, RestartType, ITEnvironemnt). 

.PARAMETER CMDBEntry
The CMDB entry that you want to display.  Possible values are "All", "MaintenanceGroup", "RestartType", and "ITEnvironment."

.PARAMETER Computer
The name of the computer that you want to get CMDB values for

.EXAMPLE
Get-CMDBEntry -CMDBEntry RestartType -Computer dcadmin8
This command gets the Restart Type from the computer's registry and from the server inventory in Sharepoint for computer DCADMIN8.

.EXAMPLE
Get-CMDBEntry -CMDBEntry All -Computer dcadmin8
This command gets all of the maintenance values (MaintenanceGroup, MaintenanceRestartType, ITEnvironment) from the computer's registry and from the server inventory in Sharepoint for computer DCADMIN8.

#>
function Get-CMDBEntry
{
	[CmdletBinding(supportsshouldprocess = $True, DefaultParameterSetName = "Default")]
	param (
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[System.String]$CMDBEntry,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Computer,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
		[hashtable]$CMDBProps,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Sharepoint")]
		[ValidateNotNullOrEmpty()]
		[switch]$Sharepoint,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Registry")]
		[ValidateNotNullOrEmpty()]
		[switch]$Registry,
		[parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Default")]
		[ValidateNotNullOrEmpty()]
		[switch]$Both,
		[parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[switch]$NoPing
		
		
	)
	
	BEGIN
	{
		
		$uri = 'http://dcappprd158/netops/_vti_bin/lists.asmx?wsdl'
		$listName = 'ServerInventory'
		if ($CMDBProps -eq $null)
		{
			$CMDBProps = $CMDBPropTable
		}
		$Value = $null
		$SPValue = $null
		$SPItem = $null
		
	}
	PROCESS
	{
		
		$service = New-WebServiceProxy -UseDefaultCredential -uri $uri	# create the web service
		$SPItem = get-spListItems -listName $listName -service $service | where { $_.ows_title -eq $computer }
		
		# Get CMDB EntryValue from Server Registry
		if (!$NoPing)
		{
			try
			{
				$PingResult = (get-ping -computer $computer).Result
			}
			catch
			{
				Write-Warning "Can't ping Computer: $computer"
				return
			}
			Write-Verbose "Pinging"
		}
		
		
		if ($NoPing -or ($PingResult -eq "PASS"))
		{
			$Values = @()
			
			if ($PsCmdlet.ParameterSetName -ne "Sharepoint")
			{
				try
				{
					$RegValues = get-csgpRegistryKeyValue -computer $computer -registryhive LocalMachine -key "SYSTEM\CoStar\CMDB"
				}
				catch
				{
					$RegValues = @()
				}
			}
			
			foreach ($entry in $CMDBProps.Keys)
			{
				$CMDBValues = ($CMDBProps.$entry).split("|")
				$Value = New-Object PSObject
				$Value | Add-Member NoteProperty Name $entry
				
				
				Write-Verbose "Getting $entry Value for $Computer..."
				if ($PsCmdlet.ParameterSetName -ne "Sharepoint")
				{
					try
					{
						$RegValue = ($RegValues | ? { $_.ValueName -eq $CMDBValues[2] } | Select ValueData).ValueData
					}
					catch
					{
						$RegValue = ""
					}
					
					if ($RegValue -eq $null)
					{
						$RegValue = ""
					}
					
					$Value | Add-Member NoteProperty RegistryValue $RegValue
					Write-Verbose "Registry Value: $RegValue"
				}
				
				$SPValue = ${SPItem}.($CMDBValues[0])
				if ($SPValue -eq $null)
				{
					$SPValue = ""
				}
				$Value | Add-Member NoteProperty SharepointValue $SPValue
				Write-Verbose "Sharepoint Value: $SPValue"
				$Values += $Value
				
			}
			
			if (!$CMDBEntry)
			{
				Write-Verbose -Message "Getting All CMDB Values"
				if ($PsCmdlet.ParameterSetName -eq "Sharepoint")
				{
					Write-Output $Values | Select-Object Name, SharepointValue
				}
				elseif ($PsCmdlet.ParameterSetName -eq "Registry")
				{
					Write-Output $Values | Select-Object Name, RegistryValue
				}
				else
				{
					Write-Output $Values
				}
			}
			elseif ($CMDBProps.ContainsKey($CMDBEntry))
			{
				if ($PsCmdlet.ParameterSetName -eq "Sharepoint")
				{
					Write-Output $Values | Where-Object { $_.Name -eq $CMDBEntry } | Select-Object Name, SharepointValue
				}
				elseif ($PsCmdlet.ParameterSetName -eq "Registry")
				{
					Write-Output $Values | Where-Object { $_.Name -eq $CMDBEntry } | Select-Object Name, RegistryValue
				}
				else
				{
					Write-Output $Values | Where-Object { $_.Name -eq $CMDBEntry }
				}
				
			}
			else
			{
				Write-Output "Not a recognized value please use one of the values below:"
				Write-Output ($CMDBProps.Keys | Sort-Object)
			}
			
			
		}
		else
		{
			Write-Warning -Message "Cannot ping server $computer"
		}
		
		
	}
	END
	{
		$Value = $null
		$SPValue = $null
		$SPItem = $null
	}
	
}

<#
.SYNOPSIS
Set CMDB values in a computer's registry and in the Server Inventory
Version 1.00

.DESCRIPTION
Set-CMDBEntry sets the CMDB entry values "MaintenanceGroup", "MaintenanceRestartType", and "ITEnvironment" in the registry of the server(s) and in the server inventory for the server(s) specified.

It will set CMDB values for the value specified (MaintenanceGroup, RestartType, ITEnvironemnt). 

.PARAMETER CMDBEntry
The CMDB entry that you want to display.  Possible values are "All", "MaintenanceGroup", "RestartType", and "ITEnvironment."

.PARAMETER Computer
The name of the computer that you want to get CMDB values for

.PARAMETER Value
The value of the CMDBEntry to set (i.e. set the RestartType to "Automatic", or the "ITEnvironment" to DEV) 

.EXAMPLE
Set-CMDBEntry -CMDBEntry RestartType -Computer dcadmin8 -Value Automatic
This command sets the Restart Type to Automatic in the computer's registry and in Server Inventory for computer DCADMIN8.

.EXAMPLE
Set-CMDBEntry -CMDBEntry All -Computer dcadmin8 -ITEnvironment PRD
This command sets the ITEnvironment CMDBEntry to a value of "PRD" in the computer's registry and in Server Inventory for computer DCADMIN8.
#>
function Set-CMDBEntry
{
	[CmdletBinding(supportsshouldprocess = $True, DefaultParameterSetName = "Default")]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$CMDBEntry,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Computer,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Default")]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Sharepoint")]
		[ValidateNotNullOrEmpty()]
		[switch]$MatchSharepoint,
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Registry")]
		[ValidateNotNullOrEmpty()]
		[switch]$MatchRegistry,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[hashtable]$CMDBProps,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[ValidateNotNullOrEmpty()]
		[bool]$ShowValue = $true
	)
	
	BEGIN
	{
		$uri = 'http://dcappprd158/netops/_vti_bin/lists.asmx?wsdl'
		$listName = 'ServerInventory'
		if ($CMDBProps -eq $null)
		{
			$CMDBProps = $CMDBPropTable
		}
		$SPItem = $null
		
	}
	PROCESS
	{
		
		# Set CMDB EntryValue in Server Registry
		$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
		
		try
		{
			$PingResult = (get-ping -computer $computer).Result
		}
		catch
		{
			Write-Warning "Can't ping Computer: $computer"
			return
		}
		
		
		
		if ($PingResult -eq "PASS")
		{
			if (($CMDBProps.ContainsKey($CMDBEntry)))
			{
				$CMDBValues = ($CMDBProps.$CMDBEntry).split("|")
				
				if ($PsCmdlet.ParameterSetName -eq "Sharepoint")
				{
					try
					{
						$NewValue = (Get-CMDBEntry -CMDBEntry $CMDBEntry -Computer $Computer -Sharepoint -Verbose:$false -NoPing).SharepointValue
					}
					catch
					{
						Write-Warning "Couldn't retrieve proper value to set, skipping setting the $CMDBEntry on $Computer"
						return
					}
				}
				elseif ($PsCmdlet.ParameterSetName -eq "Registry")
				{
					try
					{
						$NewValue = (Get-CMDBEntry -CMDBEntry $CMDBEntry -Computer $Computer -Registry -Verbose:$false -NoPing).RegistryValue
					}
					catch
					{
						Write-Warning "Couldn't retrieve proper value to set, skipping setting the $CMDBEntry on $Computer"
						return
					}
				}
				else
				{
					$NewValue = $Value
				}
				# Set Computer Registry
				
				# Test to see if we have basic registry connectivity to the server
				Write-Verbose -Message "Checking registry access to $computer..."
				try
				{
					get-csgpRegistryKey -computer $computer -registryhive LocalMachine -key "SYSTEM\CoStar" | Out-Null
				}
				catch
				{
					Write-Warning "We either don't have access or the Costar Key is not created yet"
				}
				
				# Add our CMDB key
				Write-Verbose -Message "Creating CoStar CMDB registry key on $computer..."
				try
				{
					new-csgpRegistryKey -computer $computer -registryhive LocalMachine -key "SYSTEM" -newkey "Costar\CMDB" | Out-Null
				}
				catch
				{
					Write-Warning "We may not have access to this server"
				}
				
				# Create/Set the necessary registry value for the entry we are trying to change
				Write-Verbose -Message "Setting $CMDBEntry registry value on $computer..."
				try
				{
					set-csgpRegistryKeyValue -computer $computer -key "SYSTEM\Costar\CMDB" -registryHive LocalMachine -valName $CMDBValues[2] -valData $NewValue -valueKind string | Out-Null
				}
				catch
				{
					Write-Warning "We may not have access to this server"
				}
				
				
				$SPKey = $CMDBValues[1]
				
				# Set Server Inventory Value
				$xmlFields = @"
			"<Field Name='$SPKey'>$NewValue</Field>"
"@
				
				$SPItem = get-spListItems -listName $listName -service $service | where { $_.ows_title -eq $computer }
				
				update-spListItem -rowID $SPItem.ows_ID -xmlFields $xmlFields -listName $listName -service $service
				
				if ($ShowValue -eq $true)
				{
					Get-CMDBEntry -CMDBEntry $CMDBEntry -Computer $Computer -NoPing | Out-String
				}
			}
			else
			{
				Write-Output "Please specify a valid CMDB property"
				Write-Output ($CMDBProps.Keys | Sort-Object)
			}
		}
		else
		{
			Write-Warning -Message "Cannot ping server $computer"
		}
		
		
		
		
		
	}
	END
	{
		$SPItem = $null
	}
	
}


function Get-CMDBDiffer
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[System.String]$CMDBEntry,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[hashtable]$CMDBProps,
		[Parameter(Mandatory = $false)]
		[ValidateRange(1, 800)]
		[Int]$Days = 7
	)
	
	
	begin
	{
		$uri = 'http://dcappprd158/netops/_vti_bin/lists.asmx?wsdl'
		$listName = 'ServerInventory'
		if ($CMDBProps -eq $null)
		{
			$CMDBProps = $CMDBPropTable
		}
		$SPItems = $null
		$Computers = @()
		
	}
	process
	{
		$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
		try
		{
			$SPItems = (get-spListItems -listName $listName -service $service | where { ($_.ows_hoststatus -eq "Active") -and ($_.ows_datacentercountry -eq "US") -and ($_.ows_ostype -eq "Windows") -and ([datetime]$_.ows_modified -gt (Get-Date).AddDays(- $Days)) } | select ows_title) | Select -ExpandProperty ows_title
		}
		catch
		{
			Write-Error "Could not get Sharepoint list items"
		}
		
		foreach ($SPItem in $SPItems)
		{
			
			Write-Verbose "Entries for Computer: $SPItem`n"
			
			try
			{
				$CMItem = Get-CMDBEntry -Computer $SPItem -Verbose:$false
			}
			catch
			{
				Write-Warning "Error getting info for Computer: $SPItem"
				continue
			}
			
			$Differs = $false
			
			if ($CMDBEntry)
			{
				if (($CMDBProps.ContainsKey($CMDBEntry)))
				{
					$RegValue = $CMItem | where { $_.Name -eq $CMDBEntry } | Select -ExpandProperty RegistryValue
					$SPValue = $CMItem | where { $_.Name -eq $CMDBEntry } | Select -ExpandProperty SharepointValue
					if ($RegValue -ne $SPValue)
					{
						Write-Verbose "CMDBEntry: $CMDBEntry differs for $SPItem`n"
						$Differs = $true
					}
				}
				else
				{
					Write-Error "Please specify a valid CMDB property"
					Write-Error ($CMDBProps.Keys | Sort-Object)
				}
			}
			else
			{
				foreach ($entry in $CMDBProps.Keys)
				{
					$RegValue = $CMItem | where { $_.Name -eq $entry } | Select -ExpandProperty RegistryValue
					$SPValue = $CMItem | where { $_.Name -eq $entry } | Select -ExpandProperty SharepointValue
					if ($RegValue -ne $SPValue)
					{
						Write-Verbose "CMDBEntry: $entry differs for $SPItem`n"
						$Differs = $true
					}
				}
			}
			
			if ($Differs -eq $true)
			{
				Write-Verbose "Adding $SPItem to list of computers to mitigate`n"
				$Computers += $SPItem
			}
		}
		
		Write-Output $Computers
		
	}
	end
	{
		$SPItems = $null
	}
	
}

# Syncs all CMDBEntries for a given computer based on -Sharepoint or -Registry
# Select -All to mitigate all different computers
function Sync-CMDBEntries
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ParameterSetName = "All")]
		[switch]$All,
		[Parameter(Mandatory = $true, ParameterSetName = "Single")]
		[System.String]$Computer,
		[Parameter(Mandatory = $true)]
		[ValidateSet("Sharepoint", "Registry", IgnoreCase = $true)]
		[System.String]$Prefer,
		[Parameter(Mandatory = $false)]
		[ValidateRange(1, 800)]
		[Int]$Days = 7
	)
	
	
	if ($PSCmdlet.ParameterSetName -eq "All")
	{
		$ComputerList = Get-CMDBDiffer -Days $Days
		foreach ($Comp in $ComputerList)
		{
			Sync-CMDBEntries -Computer $Comp -Prefer $Prefer
		}
	}
	else
	{
		foreach ($entry in $CMDBPropTable.Keys)
		{
			switch ($Prefer)
			{
				"Sharepoint" {
					Set-CMDBEntry -CMDBEntry $entry -Computer $Computer -MatchSharepoint -ShowValue $false 
				}
				"Registry" {
					Set-CMDBEntry -CMDBEntry $entry -Computer $Computer -MatchRegistry -ShowValue $false 
				}
				default
				{
					Set-CMDBEntry -CMDBEntry $entry -Computer $Computer -MatchSharepoint -ShowValue $false
				}
			}
		}
		
	}
}




