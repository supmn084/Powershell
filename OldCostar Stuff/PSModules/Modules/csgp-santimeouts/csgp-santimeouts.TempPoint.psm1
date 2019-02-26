#REQUIRES -Version 2.0

<#  
.SYNOPSIS  
    Set timeout parameters for Windows hosts

.DESCRIPTION  
    This script is also undoing many years of Equallogic host timeouts.  The Equallogic
active/passive arrays required longer host timeout setttings.  For EMC active/active (ALUA)
arrays we we will set all timeouts back to thier defaults.

You may ask why we are setting values that would normally not be set in a default environment.
this is because it's very likely that the old Equallogic version of this script once set
those timeout settings.  we need to rever those settings.


.NOTES  
This module was once a script so the PROCESS{} block has most of the code.  It would be better if each subsection of that original script was a function
    
.EXAMPLE  
    set-initiator-timeouts.ps1 -server ServerA -action get
.EXAMPLE    
    set-initiator-timeouts.ps1 -server ServerA -action set
#>

#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

# Updated Guidance on Microsoft MPIO Settings
# http://blogs.msdn.com/b/san/archive/2011/12/02/updated-guidance-on-microsoft-mpio-settings.aspx

$emulexLdto = 60  # emulex LinkDownTimeOut
$emulexEto = 180 # emulex ExtendedTimeOut
$LinkDownTime = 15  #For clustered environments using multi-path I/O, Default 15 seconds
#
#	This value determines how long requests will be held in the device queue
#	and retried if the connection to the target is lost. If MPIO is installed
#	this value is used. If MPIO is not installed MaxRequestHoldTime is used instead.
#
#	The default value for this is 15 seconds.

$TimeOutValue = 60 # Win: general setting
# Default 60

$UseCustomPathRecoveryInterval = 0 # for MPIO
# Default = 0
# If either the UseCustomPathRecoveryInterval value or the PathRecoveryInterval
# value is zero, the driver defaults to the behavior where PathRecoveryInterval is twice that of PDORemovePeriod.

$PDORemovePeriod = 20
#  Default 20
#
#This setting controls the amount of time (in seconds) that the multipath
# pseudo-LUN will continue to remain in system memory, even after losing all paths to the device.
# When this timer value is exceeded, pending I/O operations will be failed,
# and the failure is exposed to the application rather than attempting to continue to recover active paths.
#This timer is specified in seconds.
# The default is 20 seconds. The max allowed is MAXULONG.

$PathRecoveryInterval = 0  # for MPIO, was 60, now 0 to disable
# Default = 0
# If this key exists and is set to 1, it allows the use of PathRecoveryInterval

$MaxRequestHoldTime = 60
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}\0004\Parameters
# Default is 60

$mpioKey = 'SYSTEM\CurrentControlSet\services\mpio'
$classKey1 = 'SYSTEM\CurrentControlSet\Control\Class\{4D36E97B-E325-11CE-BFC1-08002BE10318}'
$diskKey = 'SYSTEM\CurrentControlSet\Services\Disk'
$biosKey = 'Hardware\Description\System\BIOS'
$clusterSvcKey = 'SYSTEM\CurrentControlSet\services\ClusSvc'
$interfacesKey = 'SYSTEM\CurrentControlSet\services\Tcpip\Parameters\Interfaces'

$errorReport = @()

<#
.SYNOPSIS
Gets timeouts on Windows hosts
Version 1.00

.DESCRIPTION


.PARAMETER  thisVar
-computer 
.PARAMETER  thatVar

.EXAMPLE
invoke-timeouts -action Get -computer "blah"
.EXAMPLE
"blah","blah2" | invoke-timeouts -action Get 

#>

function get-alltimeouts {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$computer
)

	BEGIN
	{

	}
	PROCESS
	{
		
		try
		{
			Test-Connection -ComputerName $computer -Count 1 | Out-Null
			
			get-DiskTimeout -computer $computer
			Get-MPIOTimeout -computer $computer
			Get-LinkDownTimeResult -computer $computer
			Get-MaxRequestHoldTime -computer $computer
			get-csgpiscsiNics -computer $computer | get-tcpdelayedack
		}
		catch
		{
			Write-warning "Unable to connect to $computer"
		}
		
	}
	END
	{

	}	

}

function set-alltimeouts
{
	[CmdletBinding(supportsshouldprocess = $True)]
	param (
		[parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$computer,
		[parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $False)]
		[switch]$restart
	)
	
	BEGIN
	{
		
	}
	PROCESS
	{
		try
		{
			Test-Connection -ComputerName $computer -Count 1 | Out-Null
			
			get-DiskTimeout -computer $computer
			Get-MPIOTimeout -computer $computer
			Get-LinkDownTimeResult -computer $computer
			Get-MaxRequestHoldTime -computer $computer
			get-csgpiscsiNics -computer $computer | set-tcpdelayedack
			
			if ($restart)
			{
				Restart-Computer -ComputerName $computer
			}
		}
		
		catch
		{
			Write-warning "Unable to connect to $computer"
		}
		
		
	}
	END
	{
		
	}
	
}

function get-DiskTimeout
{
  <#
  .SYNOPSIS
  Gets the disk timeout value on the server
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer	
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		# General OS Timeouts
		#
		$resultTimeOutValue = (get-csgpRegistryKeyValue -computer $computer -registryhive LocalMachine -key $diskKey | ? { $_.ValueName -eq 'TimeoutValue' }).ValueData
		
		$result = get-csgpRegistryKeyValue -computer $computer -registryHive LOCALMACHINE -key $diskKey | ? { $_.ValueName -eq 'TimeoutValue' }
		if ($result.ValueData -eq $TimeOutValue)
		{
			$hasPassed = $true
		}
		else
		{
			$hasPassed = $false
		}
		
		$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
		$result | Add-Member -type NoteProperty -name CorrectValue -value $TimeOutValue
		$report += $result

	}
	
	End
	{
		Write-Output $report
	}
}

function set-DiskTimeout
{
  <#
  .SYNOPSIS
  Sets the disk timeout on the server
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer		
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		# General OS Timeouts
		#
		try
		{
			
			$resultTimeOutValue = (get-csgpRegistryKeyValue -computer $computer -registryhive LocalMachine -key $diskKey | ? { $_.ValueName -eq 'TimeoutValue' }).ValueData
			$result = set-csgpRegistryKeyValue -computer $computer -registryHive LOCALMACHINE -key $diskKey -valName TimeoutValue -valData $TimeOutValue -valueKind DWORD
			get-DiskTimeout -computer $computer
		}
		catch
		{
			Write-Warning "Unable to contact the remote regisry on $computer"
		}
		
		
		
		
	}
	
	End
	{
		
	}
}

function Get-ServerPlatform
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
  .PARAMETER computer
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		
		# are we VM or physical?
		$key = @()
		$SystemManufacturerResult = @()
		$key = $biosKey
		$SystemManufacturerResult = get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE  -key $key | ? { $_.ValueName -eq 'SystemManufacturer' }
		if ($SystemManufacturerResult.ValueData -like "*vmware*")
		{
			$platform = 'virtual'
			Write-output $platform
		}
		else
		{
			$platform = 'physical'
			Write-output $platform
		}
	}
	
	End
	{
		
	}
}

function Test-IsCluster
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
  .PARAMETER computer
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		# Is this a cluster?
		$key = @()
		$key = $clusterSvcKey
		try
		{
			if (get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE  -key $key | ? { $_.ValueName -eq 'Start' -and $_.ValueData -eq 2 })

			{
				#Write-host "This is a clustered server"
				$isCluster = [bool]$true
				Write-Output $isCluster
			}
		}
		Catch
		{
			#Write-Host "This is not a clustered server"
			$isCluster = [bool]$false
			Write-Output $isCluster
		}
		

		
	}
	
	End
	{
		
	}
}

function Get-LinkDownTimeResult
{
  <#
  .SYNOPSIS
  This value determines how long requests will be held in the device queue and retried if the connection to the target is lost. 
	If MPIO is installed this value is used. If MPIO is not installed MaxRequestHoldTime is used instead.

  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computername
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
		   SupportsShouldProcess = $true,
		   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$subKeys = @()
		$key = @()
		$key = $classKey1
		$keys = get-csgpRegistryKey -computer $computer -registryhive LOCALMACHINE  -key $key
				
		foreach ($subKey in $Keys)
		{
			try
			{
				if (($linkDownTimeResult = get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE  -key "$key\$($subKey.subkeyname)\Parameters" | ? { $_.ValueName -eq 'LinkDownTime' }))
				{
					#write-host "This is a cluster LinkDownTimeOut = $($linkDownTimeResult.valuedata)"
					
					if ($($linkDownTimeResult.valuedata) -eq $LinkDownTime)
					{
						$hasPassed = 'True'
					}
					else
					{
						$hasPassed = 'False'
					}
					
					$linkDownTimeResult | Add-Member -type NoteProperty -name Pass -value $hasPassed
					$linkDownTimeResult | Add-Member -type NoteProperty -name CorrectValue -value $LinkDownTime
					$report += $linkDownTimeResult
					Write-Output $report
				}
			}
			catch
			{
				
			}
		}

		
	}
	
	End
	{
		
	}
}

function Set-LinkDownTimeResult
{
  <#
  .SYNOPSIS
  This value determines how long requests will be held in the device queue and retried if the connection to the target is lost. 
	If MPIO is installed this value is used. If MPIO is not installed MaxRequestHoldTime is used instead.

  .DESCRIPTION

  .EXAMPLE

  .EXAMPLE

  .PARAMETER computername

  .PARAMETER logname

  #>
	[CmdletBinding(
	   SupportsShouldProcess = $true,
	   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		$subKeys = @()
		$key = @()
		$key = $classKey1
		$keys = get-csgpRegistryKey -computer $computer -registryhive LOCALMACHINE  -key $key
		
		foreach ($subKey in $Keys)
		{
			try
			{
				if (($linkDownTimeResult = get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE  -key "$key\$($subKey.subkeyname)\Parameters" | ? { $_.ValueName -eq 'LinkDownTime' }))
				{
					#write-host "This is a cluster LinkDownTimeOut = $($linkDownTimeResult.valuedata)"
					
					if ($($linkDownTimeResult.valuedata) -ne $LinkDownTime)
					{
						set-csgpRegistryKeyValue -computer $computer -registryHive LOCALMACHINE -key "$key\$($subKey.subkeyname)\Parameters" -valName LinkDownTime -valData $LinkDownTime -valueKind DWORD | Out-Null
						Get-LinkDownTimeResult -computer $computer
					}
					else
					{
						Get-LinkDownTimeResult -computer $computer
					}
				}
			}
			catch
			{
				
			}
		}
		
		
	}
	
	End
	{		
	}
}

function Get-MaxRequestHoldTime
{
  <#
  .SYNOPSIS
  MaxRequestHoldTime is only used if MPIO is not installed
  
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		# MaxRequestHoldTime
		#
		$key = @()
		$key = $classKey1
		try
		{
			# Find the parent key that contains the properties subkey and get a list of adapter indexes
			$hbaIndex = get-csgpRegistryKey -computer $computer -registryhive LOCALMACHINE  -key $key | ? { $_.SubKeyName -ne 'Properties' }
			$report = @()
			foreach ($idx in ($hbaIndex | % { $_.SubKeyName }))
			{
				# Write-verbose "(MaxRequestHoldTime): Trying $key\$idx"
				try
				{
					$result = get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE -key "$key\$idx" | ? { $_.ValueName -eq 'DriverDesc' -and $_.ValueData -eq 'Microsoft iSCSI Initiator' }
					if ($result)
					{
						write-verbose "(MaxRequestHoldTime): Found key with DriverDesc = Microsoft iSCSI Initiator $key\$idx"
						
						$result = get-csgpRegistryKeyValue -computer $computer -registryHive LOCALMACHINE -key "$key\$idx\Parameters" | ? { $_.ValueName -eq 'MaxRequestHoldTime' }
						if ($result.ValueData -eq $MaxRequestHoldTime)
						{
							$hasPassed = $true
						}
						else
						{
							$hasPassed = $false
						}
						
						$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
						$result | Add-Member -type NoteProperty -name CorrectValue -value $MaxRequestHoldTime
						$report += $result
						Write-output $report
						
					}
				}
				Catch
				{
					Continue	# Didn't find iscsi initiator anywhere
				}
			}
		}
		
		Catch
		{
			Write-host "No cluster service found" -ForegroundColor 'Yellow'
		}
		
	}
	
	End
	{
		
	}
}

function Set-MaxRequestHoldTime
{
  <#
  .SYNOPSIS
  MaxRequestHoldTime is only used if MPIO is not installed
  .DESCRIPTION
  Describe the function in more detail
  .EXAMPLE
  Give an example of how to use it
  .EXAMPLE
  Give another example of how to use it
  .PARAMETER computer
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		# MaxRequestHoldTime
		#
		$key = @()
		$key = $classKey1
		try
		{
			$hbaIndex = get-csgpRegistryKey -computer $computer -registryhive LOCALMACHINE  -key $key | ? { $_.SubKeyName -ne 'Properties' }
			foreach ($idx in ($hbaIndex | % { $_.SubKeyName }))
			{
				# Write-verbose "(MaxRequestHoldTime): Trying $key\$idx"
				try
				{
					$result = get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE -key "$key\$idx" | ? { $_.ValueName -eq 'DriverDesc' -and $_.ValueData -eq 'Microsoft iSCSI Initiator' }
					if ($result)
					{
						write-verbose "(MaxRequestHoldTime): Found key with DriverDesc = Microsoft iSCSI Initiator $key\$idx"
						set-csgpRegistryKeyValue -computer $computer -registryHive LOCALMACHINE -key "$key\$idx\Parameters" -valName MaxRequestHoldTime -valData $MaxRequestHoldTime -valueKind DWORD | Out-Null
						Get-MaxRequestHoldTime -computer $computer
						break # we did our work, let's get out of this loop
					}
				}
				Catch
				{
					Continue
				}
			}
		}
		
		Catch
		{
			Write-Verbose "No cluster service found"
		}
		
	}
	
	End
	{
		
	}
}

function Test-mpio
{
  <#
  .SYNOPSIS
  See if MPIO is installed on this server
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		#	Are we running MPIO?
		$key = @()
		$key = $mpioKey
		$report = @()
		
		try
		{
			$mpioStartValue = (get-csgpRegistryKeyValue -computer $computer -registryhive LOCALMACHINE  -key $key | ? { $_.ValueName -eq 'Start' }).ValueData
			[boolean]$mpoiInstalled = $true
			Write-Output $mpoiInstalled
		}
		catch
		{
			[boolean]$mpoiInstalled = $false
			Write-Output $mpoiInstalled
		}
	}
	end
	{
	}
	
}

function Set-MPIOTimeout
{
  <#
  .SYNOPSIS
  Sets MPIO settings
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#
		#		# Are we running MPIO?
		$key = @()
		$key = $mpioKey
		$report = @()
		
		
		$runsMpio = Test-mpio -computer $computer
		
		if ($runsMpio -eq $true)
			{
				Write-Verbose "`tSetting MPIO UseCustomPathRecoveryInterval"
				$result = set-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $key"\Parameters" -valName UseCustomPathRecoveryInterval -valData $UseCustomPathRecoveryInterval -valueKind DWORD
				write-verbose "`tSetting MPIO PDORemovePeriod"
				$result = set-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $key"\Parameters" -valName PDORemovePeriod -valData $PDORemovePeriod -valueKind DWORD
				write-verbose "`tSetting MPIO PathRecoveryInterval"
				$result = set-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $key"\Parameters" -valName PathRecoveryInterval -valData $PathRecoveryInterval -valueKind DWORD
				
				write-output $(Get-MPIOTimeout -computer $computer)
			}
	}
	
	End
	{
		
	}
}

function Get-MPIOTimeout
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
  .PARAMETER computer
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
		[string]$computer
	)
	
	begin
	{
		
	}
	
	process
	{
		
		#		# Are we running MPIO?
		$key = @()
		$mkey = $mpiokey
		$report = @()
		
		$runsMpio = Test-mpio -computer $computer
		
		if ($runsMpio -eq $true)		
			{
				write-verbose "Confirmed MPIO service is started on $computer"
				
				Write-Verbose "`tGetting MPIO UseCustomPathRecoveryInterval"
				try
				{
					$result = get-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $key"\Parameters" | ? { $_.ValueName -eq 'UseCustomPathRecoveryInterval' }
					$UseCustomPathRecoveryInterval_Value = $result.ValueData
					if ($UseCustomPathRecoveryInterval_Value -eq $UseCustomPathRecoveryInterval)
					{
						$hasPassed = $true
					}
					else
					{
						$hasPassed = $false
					}
					
					$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
					$result | Add-Member -type NoteProperty -name CorrectValue -value $UseCustomPathRecoveryInterval
					$report += $result
					
					
				}
				catch
				{
					# Write-warning "Could not obtain `$UseCustomPathRecoveryInterval_Value"
				}
				
				write-verbose "`tGetting MPIO PDORemovePeriod"
				try
				{
					$result = get-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $key"\Parameters" | ? { $_.ValueName -eq 'PDORemovePeriod' }
					$PDORemovePeriod_Value = $result.ValueData
					if ($PDORemovePeriod_Value -eq $PDORemovePeriod)
					{
						$hasPassed = $true
					}
					else
					{
						$hasPassed = $false
					}
					
					$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
					$result | Add-Member -type NoteProperty -name CorrectValue -value $PDORemovePeriod
					$report += $result
					
					
				}
				catch
				{
					# Write-warning "Could not obtain `$PDORemovePeriod_Value"
				}
				
				write-verbose "`tGetting MPIO PathRecoveryInterval"
				try
				{
					$result = get-csgpRegistryKeyValue -computer $computer -registryHive LocalMachine -key $mpiokey"\Parameters" | ? { $_.ValueName -eq 'PathRecoveryInterval' }
					$PathRecoveryInterval_value = $result.ValueData
					if ($PathRecoveryInterval_value -eq $PathRecoveryInterval)
					{
						$hasPassed = $true
					}
					else
					{
						$hasPassed = $false
					}
					
					$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
					$result | Add-Member -type NoteProperty -name CorrectValue -value $PathRecoveryInterval
					$report += $result
					
					
				}
				catch
				{
					# Write-warning "Could not obtain `$PathRecoveryInterval_value"
				}
				
				
				Write-Output $report
			}

	}
	
	End
	{
		
	}
}

function get-csgpiscsiNics
{
	<#
  .SYNOPSIS
  Given a servername, locates the nics that are on iSCSI networks
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(supportsshouldprocess = $true)]
	param (
		# Computer to connect to
		[Parameter(Mandatory = $True, ValueFromPipeline = $true)]
		[string]$computer
	)
	
	BEGIN
	{
		
		# Add new iscsi networks into this array.  Right now, we assume each network is a /24
		#	smaller networks like /25 won't work.
		#	larger networks like /22 can be split into multiple /24
		$iscsiNetworks = @(
		'192.168.20.', # Reston Equallogic
		'192.168.21.', # Reston Equallogic
		'192.168.22.', # Reston Equallogic
		'192.168.23.', # Reston Equallogic
		'192.168.90.', # Reston EMC
		'192.168.91.', # Reston EMC
		'192.168.96.', # Reston EMC
		'192.168.97.', # Reston EMC
		'192.168.98.', # Reston EMC
		'192.168.99.', # Reston EMC
		'192.168.27.', # Vienna Equallogic / original VNX
		'192.168.124', # Vienna EMC
		'192.168.125', # Vienna EMC
		'192.168.126', # Vienna EMC
		'192.168.127', # Vienna EMC
		'192.168.128', # Vienna EMC
		'192.168.129', # Vienna EMC
		'192.168.110', # LAX EMC
		'192.168.111', # LAX EMC
		'192.168.112', # LAX EMC
		'192.168.113', # LAX EMC
		'192.168.114', # LAX EMC
		'192.168.115', # LAX EMC
		'192.168.19.', # LAX Equallogic
		'192.168.43.'	# LAX Virtual premise
		)
		
	}
	
	PROCESS
	{
		$osVersion = (gwmi Win32_OperatingSystem -ComputerName $computer).version
		if ($osVersion -like "5.2*")
		{
			write-verbose "$computer has Server 2003 OS, not supported to for Delayed Ack"
			Return
		}
		$networkAdapters = gwmi Win32_NetworkAdapter -ComputerName $computer
		$NetworkAdapterConfigurations = gwmi Win32_NetworkAdapterConfiguration -ComputerName $computer
		
		
		foreach ($netAdapter in $networkAdapters)
		{
			foreach ($NetworkAdapterConfiguration in $NetworkAdapterConfigurations)
			{
				# $NetworkAdapterConfiguration has the IP info we need
				if ($NetworkAdapterConfiguration.SettingID -eq $netAdapter.GUID)
				{
					# we've matched both WMI classes to the same NIC
					foreach ($nicIP in $NetworkAdapterConfiguration.IPAddress)
					{
						# $NetworkAdapterConfiguration.IPAddress is an array of IP addresses
						foreach ($iscsiNetwork in $iscsiNetworks)
						{
							# Now start looping through our list of known iSCSI networks and see if we can match
							if ($nicIP -like "$iscsiNetwork*")
							{
								[PSCustomObject]$obj = @()
								$obj = "" | Select-Object Computer, NetConnectionID, GUID, IPAddress, MacAddress, InterfaceIndex
								$obj.Computer = $computer
								$obj.NetConnectionID = $netAdapter.NetConnectionID
								$obj.GUID = $netAdapter.GUID
								$obj.IPAddress = $nicIP
								$obj.MacAddress = $netAdapter.MacAddress
								$obj.InterfaceIndex = $NetworkAdapterConfiguration.InterfaceIndex
								write-output $obj
							}
						}
					}
				}
				
			}
		}
	}
	END
	{
		
	}
}

function get-tcpdelayedack
{
  <#
  .SYNOPSIS
  Check to see if TCP delayed ack is enabled or disabled
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$guid	# interface guid
	)
	
	
	begin
	{
		$valName = 'TcpAckFrequency'
		$valData = '1'
		$key = $interfacesKey
	}

	process
	{
		
		$report = @()
		Write-Verbose "guid is: $guid"
		$result = get-csgpRegistryKeyValue -computer $computer -key $key"\"$Guid -registryHive LocalMachine | ? { $_.ValueName -eq $valName }
		
		if ($result.ValueData -eq $valData)
		{
			$hasPassed = $true
		}
		else
		{
			$hasPassed = $false
		}
		
		$result | Add-Member -type NoteProperty -name Pass -value $hasPassed
		$result | Add-Member -type NoteProperty -name CorrectValue -value $valData
		$report += $result
		
		Write-Output $report
	}
	
	end
	{
	}
	
}

function set-tcpdelayedack
{
  <#
  .SYNOPSIS
  Disable TCP Delayed ack (helps with latency issues)
  .DESCRIPTION
  
  .EXAMPLE
  
  .EXAMPLE
  
  .PARAMETER computer
  
  .PARAMETER logname
  
  #>
	[CmdletBinding(
				   SupportsShouldProcess = $true,
				   ConfirmImpact = "High"
	)]
	
	param
	(
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$computer,
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = 'What computer name would you like to target?')]
		[string]$guid	# interface guid
	)
	
	
	begin
	{
		$valName = 'TcpAckFrequency'
		$valData = '1'
		$valueKind = 'DWORD'
		$key = $interfacesKey
		
	}
	
	process
	{
		
		$report = @()
		Write-Verbose "guid is: $guid"
		$result = set-csgpRegistryKeyValue -computer $computer -key $key"\"$guid -registryHive LocalMachine -ValName $valName -valData $valData -valueKind $valueKind
		
		# have to filter out each GUID or we get 2x more results than needed beause get-csgpiscsiNics outputs > 1 nic/guid
		write-output $(get-csgpiscsiNics -computer $computer | ? { $_.Guid -eq $guid } | get-tcpdelayedack)
	}
	
	end
	{
	}
	
}

