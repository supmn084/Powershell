Set-StrictMode -version 2
$ErrorActionPreference = "Continue"

<#
.SYNOPSIS
get-csgpRegistryKey will tell us if a key exists.  Output is all the subkeys in this key (if any).
Emtpy if no subkeys

Version 1.00

.DESCRIPTION
You may use try{} catch{} to see if the key exists.  If a key with no subkeys
is found we return an empty object

.EXAMPLE
import-module csgp-registry2 -force; 
get-csgpRegistryKey -computer dcadmin8 -registryhive LocalMachine -key "SYSTEM\Costar\CMDB"


#>
function get-csgpRegistryKey {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	# The computer you want to connect to
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$computer,
	# Specify the base registry key (like "SOFTWARE\Microsoft\Windows\CurrentVersion")
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$key,
	# Specify the registry hive (ClassesRoot, CurrentConfig, LocalMachine, CurrentUser, Users)
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$registryhive
)

	BEGIN	{
		$report = @()
	}

	
	PROCESS	{
		$regkey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($registryHive, $computer)
		if (! $regKey) { 
			write-error "${computer}:key $key not found or error occured"
		}

	    if (! ( $regSubKey = $regkey.OpenSubKey($key,$false)) ) {
					Write-Error "${computer}: Key $key not found"
		 } else {
		 	if ($regSubKey.GetSubKeyNames().count -gt 0)	{
			 	foreach ($subKeyName in $regSubKey.GetSubKeyNames() )	{
					$obj = @()
					$obj = "" | Select-Object SubKeyName
					$obj.SubKeyName = $subKeyName
					if (! $subKeyName)	{
						$obj.SubKeyName = 'null'
					}
					$report += $obj
				}
			} else {
				# Return a blank object
				$obj = @()
				$obj = "" | Select-Object SubKeyName
				$report += $obj
			}
		 }
		
		$regkey.close()
		Write-Output $report 
		
	}
	END	{

	}	

}

<#
.SYNOPSIS
new-csgpRegistryKey allows the user to create a new registry key
Version 1.00

.DESCRIPTION


.EXAMPLE
import-module csgp-registry2 -force; 
new-csgpRegistryKey -computer dcadmin8 -registryhive LocalMachine -key "SYSTEM" -newkey "CoStar"


#>
function new-csgpRegistryKey {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	# The computer you want to connect to
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$computer,
	# Specify the base registry key (like "SOFTWARE\Microsoft\Windows\CurrentVersion")
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$key,
	# Specify the new key you want to create
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$newKey,
	# Specify the registry hive (ClassesRoot, CurrentConfig, LocalMachine, CurrentUser, Users)
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$registryhive

	)

	BEGIN	{

	}

	PROCESS	{
		$regkey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($registryHive, $computer)
		if (! $regKey) { 
			write-error "${computer}:key $key not found or error occured"
		}

	    if (! ( $regSubKey = $regkey.OpenSubKey($key,$true)) ) {
					Write-Error "${computer}: Key $key not found"
		} 
		
		# Set the value data if it does not exist
		if (! ($regSubKey.CreateSubKey($newkey) ) )	{
			# Create the key
			$regSubkey.CreateSubKey($newKey)
		}
		
		$regkey.close()
		
		get-csgpRegistryKey -computer $computer -registryhive $registryHive -key "$key\$newkey"
		
	}
	END	{

	}	

}

<#
.SYNOPSIS
get-csgpRegistryKeyValue will connect to a remote (or local) computer and list all registry values in the given key
Version 1.00

.DESCRIPTION

.EXAMPLE
import-module csgp-registry2 -force; 
get-csgpRegistryKeyValue -computer dcadmin8 -key "SOFTWARE\Microsoft\Windows\CurrentVersion" -registryHive LocalMachine

.EXAMPLE
import-module csgp-registry -force; 
get-csgpRegistryKeyValue -computer dcadmin8 -key "SYSTEM\CurrentControlSet\services\Tcpip\Parameters" -registryHive LocalMachine

#>
function get-csgpRegistryKeyValue {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	# The computer you want to connect to
	[Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$true)]
	[string]$computer,
	# Specify the base registry key (like "SOFTWARE\Microsoft\Windows\CurrentVersion")
	[Parameter(Mandatory=$True,ValueFromPipeline=$false)]
	[string]$key,
	# Specify the registry hive (ClassesRoot, CurrentConfig, LocalMachine, CurrentUser, Users)
	[Parameter(Mandatory=$True,ValueFromPipeline=$false)]
	[string]$registryHive
	)

	BEGIN	{

	}

	PROCESS	{
		$type = [Microsoft.Win32.RegistryHive]::$registryHive
		$regKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($type, $computer)
		$regKey = $regKey.OpenSubKey($key)
		
		if (! $regKey) { 
			write-error "${computer}:Key $key not found or error occured"
		}

		foreach($valName in $regKey.GetValueNames())	{
			$obj = @()
			$obj = "" | Select-Object Computer,ValueName,ValueData,ValueKind
			$keyValue = $regKey.GetValue($valName)
			$valueKind = $regKey.GetValueKind($valName)	
			$obj.Computer = $computer
			$obj.ValueName = $valName
			$obj.ValueData = $keyValue
			$obj.ValueKind = $valueKind
			Write-Output $obj
		}
	}
	END	{

	}	
}

<#
.SYNOPSIS
set-csgpRegistryKeyValue allows the user to set/create an individual registry value and data
Version 1.00

.DESCRIPTION
The cmdlet returns the newly created row as an object

.EXAMPLE
import-module csgp-registry2 -force; 
set-csgpRegistryKeyValue -computer dcadmin8 -key "SYSTEM\Costar\CMDB" -registryHive LocalMachine -valName myValue -valData 2 -valueKind string -verbose


#>
function set-csgpRegistryKeyValue {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	# The computer you want to connect to
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$computer,
	# Specify the base registry key (like "SOFTWARE\Microsoft\Windows\CurrentVersion")
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$key,
	# Specify the registry hive (ClassesRoot, CurrentConfig, LocalMachine, CurrentUser, Users)
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$registryHive,
	# Specify the registry value name (like "MyValue"
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$valName,
	# Specify the registry value data (like 42 or "abc")
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$valData,
	# Specify the registry value kind (like String, ExpandString, Binary, DWord, MultiString, QWord)
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$valueKind
	)

	BEGIN	{

	}

	PROCESS	{
		$regkey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($registryHive, $computer)
		if (! $regKey) { 
			write-error "${computer}:key $key not found or error occured"
		}

	    try {
			$regSubKey = $regkey.OpenSubKey($key,$true)	# $false = RO, $true = RW
		} catch {
			Write-Error "${computer}: failed to connect to registry"
		}
		
		# Set the value data
		$regSubkey.SetValue($valName,$valData,$valueKind) # SetValue overloads are Unknown, String, ExpandString, Binary, DWord, MultiString, QWord
		
		$newValueObj = get-csgpRegistryKeyValue -computer $computer -key $key -registryHive $registryHive | ? {$_.ValueName -eq $valName}
		if (! $newValueObj)	{
			write-error "${computer}: It appears we wrote the value to $computer but we could not read it..."
		} else {
			# write object back to caller
			Write-Output $newValueObj
		}
		

		$regkey.close()
		
	}
	END	{

	}	

}


