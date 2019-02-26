

function Get-ClearPassword {
	<#
	.SYNOPSIS
		Takes a PSCredential object and returns the clear text password.

	.DESCRIPTION
		Takes a PSCredential object and returns the clear text password.

	.PARAMETER  Cred
		This is a PSCredential object. Can be created by the get-credential cmdlet.

	.EXAMPLE
		PS C:\> Get-ClearPassword -Cred (get-credential)
		This example shows how to call the Get-ClearPassword function with named parameters.

	.INPUTS
		PSCredential

	.OUTPUTS
		System.String
	
#>
	param(
		$Cred
	)
#	$bstrPassword = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Cred.Password)
#	$plainTextPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstrPassword)
#	[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstrPassword)
#	$plainTextPassword
	$Ptr=[System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($Cred.Password)
	[System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
	[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
	
}

function start-plink {
	param(
		$Cred,
		[System.String] $Chassis,
		[System.String] $cmd
	)
	#(plink -auto_store_key_in_cache -l $($cred.username) -pw $(get-clearpassword($cred)) $chassis $cmd)
	
	Write-Host "Running plink -l $($cred.username) -pw xxx $chassis $cmd" 
	(plink.exe -l $($cred.username) -pw $(get-clearpassword($cred)) $chassis $cmd)
	
}
function Get-HPVCDeviceBay  {
<#
	.SYNOPSIS
		Gets the Virtual Connect DeviceBays.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the DeviceBays as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCDeviceBay -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCDeviceBay 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCDeviceBay

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show DeviceBay * -output=script2'
			$DeviceBay = New-Object "HPVCDeviceBay"
			[HPVCDeviceBay[]] $array = @()
			$DeviceBay.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$DeviceBay.ID, $DeviceBay.EnclosureName, $DeviceBay.Bay, $DeviceBay.Device, $DeviceBay.Profile = $subject[$i] -split ";"

				$array += $DeviceBay
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Get-HPVCFirmware  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Firmware.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Firmware versions as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCFirmware -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCFirmware 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCFirmware

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Firmware * -output=script2'
			$Firmware = New-Object "HPVCFirmware"
			[HPVCFirmware[]] $array = @()
			$Firmware.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$Firmware.ID, $Firmware.Enclosure, $Firmware.Bay, $Firmware.Type, $Firmware.FirmwareVersion, $Firmware.Status = $subject[$i] -split ";"

				$array += $Firmware
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
#EndRegion
#Region Types


add-type @" 
public struct HPVCUser { 
	public string Chassis; 
	public string UserName;
	public string Privileges;
	public string FullName;
	public string ContactInfo;
	public string Enabled;
} 
"@ 

add-type @" 
public struct HPVCDeviceBay { 
	public string Chassis; 
	public string ID;
	public string EnclosureName;
	public string Bay;
	public string Device;
	public string Profile;
} 
"@ 

add-type @" 
public struct HPVCEnclosure { 
	public string Chassis; 
	public string ID;
	public string EnclosureName;
	public string Description;
	public string ImportStatus;
	public string OverallStatus;
	public string SerialNumber;
	public string PartNumber;
	public string AssetTag;
	public string NumDeviceBays;
	public string NumIOBays;
	public string Manufacturer;
	public string SparePartNumber;
	public string SpareRackName;
	public string Primary;
	public string OA1IPAddress;
	public string OA2IPAddress;
	public string CommStatus;
} 
"@ 

add-type @" 
public struct HPVCenetconnection { 
   public string Chassis; 
   public string Profile; 
   public string Port;
   public string NetworkName;
   public string PXE;
   public string MAC;
   public string AllocSpeed;
   public string Status;
} 
"@ 

add-type @" 
public struct HPVCProfileEnetConnection { 
   public string Chassis; 
   public string Profile; 
   public string Port;
   public string Server;
   public string NetworkName;
   public string McastFilter;
   public string PXE;
   public string MAC;
   public string ConfSpeed;
   public string MinAllocSpeed;
   public string MaxAllocSpeed;
   public string PortMap;
   public string Status;
} 
"@ 

add-type @" 
public struct HPVCenetvlan { 
   	public string Chassis; 
	public string VLANTagControl;
	public string SharedServerVLANID;
	public string PreferredSpeed;
	public string MaxSpeed;
} 
"@ 

add-type @" 
public struct HPVCFirmware { 
   	public string Chassis; 
	public string ID;
	public string Enclosure;
	public string Bay;
	public string Type;
	public string FirmwareVersion;
	public string Status;
} 
"@ 

add-type @" 
public struct HPVCIGMP { 
   	public string Chassis; 
	public string Enabled;
	public string Timeout;
} 
"@ 

add-type @" 
	public struct HPVCNetwork { 
	public string Chassis; 
	public string Name;
	public string Status;
	public string SmartLink;
	public string State;
	public string ConnectionMode;
	public string SharedUplinkSet;
	public string VLANID;
	public string NativeVLAN;
	public string Private;
	public string VLANTunnel;
	public string PreferredSpeed;
	public string MaxSpeed;
} 
"@ 

add-type @" 
public struct HPVCInterconnect { 
   	public string Chassis; 
	public string ID;
	public string Enclosure;
	public string Bay;
	public string Type;
	public string ProductName;
	public string Status;
	public string CommStatus;
	public string OAStatus;
	public string PowerState;
	public string MACAddress;
	public string FirmwareVersion;
	public string Manufacturer;
	public string PartNumber;
	public string SparePartNumber;
	public string RackName;
	public string SerialNumber;
	public string UID;
} 
"@ 

add-type @" 
public struct HPVCLdap { 
   	public string Chassis; 
	public string Enabled;
	public string LocalUsers;
	public string NTAccountMapping;
	public string ServerAddress;
	public string SSLPort;
	public string SearchContext1;
	public string SearchContext2;
	public string SearchContext3;
} 
"@ 

add-type @" 
public struct HPVCLdapGroup { 
   	public string Chassis; 
	public string Name;
	public string Privileges;
	public string Description;
} 
"@ 

add-type @" 
public struct HPVCMacCache { 
   	public string Chassis; 
	public string Enabled;
	public string RefreshInterval;
} 
"@ 

add-type @" 
public struct HPVCProfile { 
   	public string Chassis; 
	public string Name;
	public string DeviceBay;
	public string Server;
	public string Status;
} 
"@ 

add-type @" 
public struct HPVCServer { 
   	public string Chassis; 
	public string ServerID;
	public string EnclosureName;
	public string EnclosureID;
	public string Bay;
	public string Description;
	public string Status;
	public string Power;
	public string UID;
	public string ServerProfile;
	public string Height;
	public string Width;
	public string PartNumber;
	public string SerialNumber;
	public string ServerName;
	public string OSName;
	public string AssetTag;
	public string ROMVersion;
	public string Memory;
} 
"@ 

add-type @" 
public struct HPVCServerPort { 
   	public string Chassis; 
	public string Port;
	public string Server;
	public string IOModule;
	public string AdapterType;
	public string ID;
	public string Profile;
} 
"@ 

add-type @" 
public struct HPVCSnmp { 
   	public string Chassis; 
	public string Type;
	public string Enabled;
	public string CommunityName;
	public string SystemContact;
	public string SMISEnabled;
} 
"@ 

add-type @" 
public struct HPVCStackingLink { 
   	public string Chassis; 
	public string Link;
	public string Speed;
	public string ConnectedFrom;
	public string ConnectedTo;
} 
"@ 

add-type @" 
public struct HPVCStackingLinkStatus { 
   	public string Chassis; 
	public string ConnectionStatus;
	public string RedundancyStatus;
} 
"@ 

add-type @" 
public struct HPVCStatus { 
   	public string Chassis; 
	public string OverallDomainStatus;
	public string Critical;
	public string Major;
	public string Minor;
	public string Warning;
	public string Information;
	public string Unknown;
} 
"@ 

add-type @" 
public struct HPVCSystemLog { 
   	public string Chassis; 
	public string Record;
	public string DateTime;
	public string Info;
	public string Message;
} 
"@ 

add-type @" 
public struct HPVCUplinkPort { 
   	public string Chassis; 
	public string ID;
	public string Enclosure;
	public string Status;
	public string Type;
	public string Speed;
	public string UsedBy;
	public string ConnectedFrom;
	public string ConnectedTo;
} 
"@ 

add-type @" 
public struct HPVCStatistic { 
   	public string Chassis; 
	public string Name;
	public string Value;
} 
"@

add-type @" 
public struct HPVCUplinkSet { 
   	public string Chassis; 
	public string Name;
	public string Status;
} 
"@

add-type @" 
public struct HPVCUserSecurity { 
   	public string Chassis; 
	public string StrongPasswords;
	public string MinimumPasswordLength;
} 
"@

add-type @" 
public struct HPVCVersion { 
   	public string Chassis; 
	public string Version;
} 
"@

#EndRegion
#Region UplinkSet Functions
function Get-HPVCUplinkSet  {
<#
	.SYNOPSIS
		Gets the Virtual Connect UplinkSet settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the UplinkSet settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCUplinkSet -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCUplinkSet 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCUplinkSet

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show UplinkSet -output=script2'
			$UplinkSet = New-Object "HPVCUplinkSet"
			[HPVCUplinkSet[]] $array = @()
			$UplinkSet.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$UplinkSet.Name, $UplinkSet.Status = $subject[$i] -split ";"

				$array += $UplinkSet
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Set-HPVCUplinkSet  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$UplinkSetName,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set UplinkSet $UplinkSetName $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Add-HPVCUplinkSet  {
	# Modified by Costar
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$UplinkSetName
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add UplinkSet $UplinkSetName ConnectionMode=Auto"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


function Remove-HPVCUplinkSet  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$UpLinkSetName
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove UplinkSet $UplinkSetName"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


#EndRegion

#Region Network Functions
function Get-HPVCNetwork  {
<#
	.SYNOPSIS
		Gets the networks for a given blade chassis.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis and retrieve the networks as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCnetwork -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the Get-HPVCenetconnection function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCnetwork 'chassis1' $cred
		This example shows how to call the Get-HPVCenetconnection function with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		network

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show network * -output=script2'
			$network = New-Object "HPVCNetwork"
			[HPVCNetwork[]] $array = @()
			$network.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i+= 3) {
				
				$network.name, $network.Status, $network.SmartLink, $network.State, $network.ConnectionMode, $network.SharedUplinkSet, $network.VLANID, $network.NativeVLAN, $network.Private, $network.VLANTunnel, `
				$network.PreferredSpeed, $network.MaxSpeed = $subject[$i] -split ";"

				$array += $network
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Add-HPVCNetwork  {

	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string]$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[string]$NetworkName,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[string]$UplinkSet,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[int]$VLanId
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add network $NetworkName UplinkSet=$UplinkSet VLanID=$VLanID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCNetwork  {

	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string]$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[string]$NetworkName,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[string]$SmartLink
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $NetworkName SmartLink=$SmartLink"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Disable-HPVCSmartLink  {
<#
	.SYNOPSIS
		Disables SmartLink on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to disable SmartLink on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to disable SmartLink on.

	.EXAMPLE
		PS C:\> Disable-HPVCSmartLink -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network SmartLink=Disabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Enable-HPVCSmartLink  {
<#
	.SYNOPSIS
		Enable SmartLink on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to enable SmartLink on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to enable SmartLink on.

	.EXAMPLE
		PS C:\> Enable-HPVCSmartLink -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network SmartLink=Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Disable-HPVCNativeVLAN  {
<#
	.SYNOPSIS
		Disables NativeVLAN on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to disable NativeVLAN on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to disable NativeVLAN on.

	.EXAMPLE
		PS C:\> Disable-HPVCNativeVLAN -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network NativeVLAN=Disabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Enable-HPVCNativeVLAN  {
<#
	.SYNOPSIS
		Enable NativeVLAN on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to enable NativeVLAN on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to enable NavtiveVLAN on.

	.EXAMPLE
		PS C:\> Enable-HPVCNativeVLAN -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network NativeVLAN=Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Disable-HPVCPrivate  {
<#
	.SYNOPSIS
		Disables Private on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to disable Private on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to disable Private on.

	.EXAMPLE
		PS C:\> Disable-HPVCPrivate -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network Private=Disabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Enable-HPVCPrivate  {
<#
	.SYNOPSIS
		Enable Private on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to enable Private on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to enable NavtiveVLAN on.

	.EXAMPLE
		PS C:\> Enable-HPVCPrivate -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network Private=Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Disable-HPVCVLANTunnel  {
<#
	.SYNOPSIS
		Disables VLANTunnel on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to disable VLANTunnel on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to disable VLANTunnel on.

	.EXAMPLE
		PS C:\> Disable-HPVCVLANTunnel -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network VLANTunnel=Disabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Enable-HPVCVLANTunnel  {
<#
	.SYNOPSIS
		Enable VLANTunnel on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to enable VLANTunnel on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to enable NavtiveVLAN on.

	.EXAMPLE
		PS C:\> Enable-HPVCVLANTunnel -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network VLANTunnel=Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Disable-HPVCNetwork  {
<#
	.SYNOPSIS
		Disables Network on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to disable Network on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to disable Network on.

	.EXAMPLE
		PS C:\> Disable-HPVCNetwork -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network State=Disabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Enable-HPVCNetwork  {
<#
	.SYNOPSIS
		Enable Network on a network.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to enable Network on a network.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Network
		This is the Network which you want to enable NavtiveVLAN on.

	.EXAMPLE
		PS C:\> Enable-HPVCNetwork -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Network
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set network $Network State=Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region User Functions
function Get-HPVCUser  {
<#
	.SYNOPSIS
		Gets the Virtual Connect users.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the users as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCUser -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCUser 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCUser

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show user * -output=script2'
			$User = New-Object "HPVCUser"
			[HPVCUser[]] $array = @()
			$User.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i+= 3) {
				
				$User.UserName, $User.Privileges, $User.FullName, $User.ContactInfo, $User.Enabled = $subject[$i] -split ";"

				$array += $User
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCUser  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$User,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set User $User $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Add-HPVCUser  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$User,
		[Parameter(Position=3)]
		$Password
		)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add User $User $Password"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCUser  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$User
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove User $User"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Get-HPVCUserSecurity  {
<#
	.SYNOPSIS
		Gets the Virtual Connect UserSecuritys.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the UserSecuritys as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the UserSecurityname and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCUserSecurity -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCUserSecurity 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCUserSecurity

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show User-Security -output=script2'
			$UserSecurity = New-Object "HPVCUserSecurity"
			[HPVCUserSecurity[]] $array = @()
			$UserSecurity.Chassis = $Chassis
			for ($i = 1; $i -lt 2; $i++) {
				
				$UserSecurity.StrongPasswords, $UserSecurity.MinimumPasswordLength = $subject[$i] -split ";"

				$array += $UserSecurity
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCUserSecurity  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set User-Security $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region IGMP
function Get-HPVCIGMP  {
<#
	.SYNOPSIS
		Gets the Virtual Connect IGMP settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the IGMP settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCIGMP -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCIGMP 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCIGMP

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show IGMP -output=script2'
			$IGMP = New-Object "HPVCIGMP"
			[HPVCIGMP[]] $array = @()
			$IGMP.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$IGMP.Enabled, $IGMP.Timeout = $subject[$i] -split ";"

				$array += $IGMP
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCIGMP  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Enabled
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set IGMP Enabled=$Enabled"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCIGMPTimeout  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Timeout
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set IGMP Timeout=$Timeout"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region Enclosure Functions
function Get-HPVCEnclosure  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Enclosures.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Enclosures as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCEnclosure -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCEnclosure 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCEnclosure

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Enclosure * -output=script2'
			$Enclosure = New-Object "HPVCEnclosure"
			[HPVCEnclosure[]] $array = @()
			$Enclosure.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				$Enclosure.ID, $Enclosure.EnclosureName, $Enclosure.Description, $Enclosure.ImportStatus, $Enclosure.OverallStatus, $Enclosure.SerialNumber,`
				$Enclosure.PartNumber, $Enclosure.AssetTag, $Enclosure.NumDeviceBays, $Enclosure.NumIOBays, $Enclosure.Manufacturer, $Enclosure.SparePartNumber,`
				$Enclosure.SpareRackName, $Enclosure.Primary, $Enclosure.OA1IPAddress, $Enclosure.OA2IPAddress, $Enclosure.CommStatus  = $subject[$i] -split ";"
				
				$array += $Enclosure
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Import-HPVCEnclosure  {
<#
	.SYNOPSIS
		Imports a local or remote enclosure.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to import a local or remote enclosure.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Username
		This is the username of the OA to import.
		
	.PARAMETER  Password
		This is the password of the OA to import.
		
	.PARAMETER  IPAddress
		This is the IP Address or DNS name of the OA to import. If not specified then the local enclosure will be imported.

	.EXAMPLE
		PS C:\> Import-HPVCEnclosure -Chassis 'chassis1' -Credentials $cred -Network 'TestNetwork'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Username,
		[Parameter(Position=3)]
		$Password,
		[Parameter(Position=4)]
		$IPAddress = ""
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			if ($IPAddress) {$IPAddresstxt = "IPAddress=$IPAddress"}
			$subject = start-plink $Cred $Chassis "import enclosure UserName=$Username Password=$Password $IPAddresstxt"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCEnclosure  {
<#
	.SYNOPSIS
		Removes a remote enclosure.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis to remove a remote enclosure.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  EnclosureID
		This is the enclosure ID to remove.
		
	.EXAMPLE
		PS C:\> Remove-HPVCEnclosure -Chassis 'chassis1' -Credentials $cred -EnclosureID 'Enc1'

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$EnclosureID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove enclosure $EnclosureID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region Ethernet Connection Functions

function Get-HPVCEnetConnection  {
# Modified by CoStar
<#
	.SYNOPSIS
		Gets the Virtual Connect EnetConnection settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the EnetConnection settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCEnetConnection -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCEnetConnection 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCEnetConnection

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Enet-Connection -output=script2'
			$EnetConnection = New-Object "HPVCEnetConnection"
			[HPVCEnetConnection[]] $array = @()
			$EnetConnection.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				#Profile;Port;Server;Network Name;Mcast Filter Name;PXE;MAC Address;Configured Speed;Min Allocated Speed;Max Allocated Speed;Server Port;Module Port;Status

				$EnetConnection.profile, $EnetConnection.port, $EnetConnection.networkname ,$EnetConnection.pxe,$EnetConnection.mac,$EnetConnection.Allocspeed,$EnetConnection.status = $subject[$i] -split ";"
				
				$array += $EnetConnection
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Get-HPVCProfileEnetConnection  {
# Added by CoStar
<#
	.SYNOPSIS
		Gets a specific EnetConnection setting for a single profile

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the EnetConnection settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.
		
	.PARAMETER  Computer
		This is the name of the VC profile

	.EXAMPLE
		PS C:\> Get-HPVCEnetConnection -Chassis 'chassis1' -Credentials $cred -computer SERVER1
		This example shows how to call the function with named parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCProfileEnetConnection

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$computer
	)
	begin {
		try {
			
		}
		catch {
		}
	}
	process {
	
		
		try {
			
			$subject = start-plink $Cred $Chassis "show Enet-Connection $computer -output=script2"
			$EnetConnection = New-Object "HPVCProfileEnetConnection"
			[HPVCProfileEnetConnection[]] $array = @()
			$EnetConnection.Chassis = $Chassis
			
			foreach ($line in $subject)	{
				$itemCount = @()
				#Profile;Port;Server;Network Name;Mcast Filter Name;PXE;MAC Address;Configured Speed;Min Allocated Speed;Max Allocated Speed;Server Port;Module Port;Status
				if ($line -match "^Profile") { 
					continue
				}
				if ($line -match "^---") { 
					continue
				}
				$itemCount = ($line -split ";").count
				#Write-Host "-- $line"
				
				
				# example 4.0 output
				#Profile;Port;Server;Network Name;Mcast Filter Name;PXE;MAC Address;Configured Speed;Min Allocated Speed;Max Allocated Speed;Server Port;Module Port;Status
				#DCCLUDEV400N2;4;enc0:4;INT-ISCSI01-2;None;UseBIOS;3C-D9-2B-F6-6A-BD;7Gb;7Gb;10Gb;LOM1:2-b;enc0:2:d4:v2;OK

				if ($itemCount -eq 13)	{
					#write-host "VC Firmware 4.0 or greater"
					# Profile;Port;Server;Network Name;Mcast Filter Name;PXE;MAC Address;Configured Speed;Min Allocated Speed;Max Allocated Speed;Server Port;Module Port;Status
					$EnetConnection.profile,$EnetConnection.port,$EnetConnection.Server,$EnetConnection.networkname,$EnetConnection.McastFilter,$EnetConnection.pxe,$EnetConnection.mac,$EnetConnection.ConfSpeed,$EnetConnection.MinAllocspeed,$EnetConnection.MaxAllocspeed,$EnetConnection.PortMap,$EnetConnection.status = $line -split ";"
					$array += $EnetConnection
				} else {
					#Write-Host "VC Firmware 3.x or lower"
					$EnetConnection.profile, $EnetConnection.port, $EnetConnection.Server, $EnetConnection.networkname ,$EnetConnection.pxe, $EnetConnection.mac, $EnetConnection.MinAllocspeed, $EnetConnection.ConfSpeed, $EnetConnection.PortMap, $EnetConnection.status = $line -split ";"
					$array += $EnetConnection
				}
					
			} 
			$array
		}
		catch {Write-Host Fail: $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCenetconnection  {
<#
	.SYNOPSIS
		Removes the last ethernet connections for a given blade chassis.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis and remove the last ethernet connection assigned to a profile.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Profile
		This is the profile which you want to remote the ethernet connection from.

	.EXAMPLE
		PS C:\> Remove-HPVCenetconnection -Chassis 'chassis1' -Credentials $cred -Profile 'Bay1'
		This example shows how to call the Remove-HPVCenetconnection function with named parameters.

	.EXAMPLE
		PS C:\> Remove-HPVCenetconnection 'chassis1' $cred 'Bay1'
		This example shows how to call the Remove-HPVCenetconnection function with positional parameters.

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Profile
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove enet-connection $profile"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Add-HPVCenetconnection  {
<#
	.SYNOPSIS
		Adds an ethernet connections for a given blade chassis.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis and add an ethernet connection to a profile.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Profile
		This is the profile which you want to add the ethernet connection to.

	.EXAMPLE
		PS C:\> Remove-HPVCenetconnection -Chassis 'chassis1' -Credentials $cred -Profile 'Bay1'
		This example shows how to call the Remove-HPVCenetconnection function with named parameters.

	.EXAMPLE
		PS C:\> Remove-HPVCenetconnection 'chassis1' $cred 'Bay1'
		This example shows how to call the Remove-HPVCenetconnection function with positional parameters.

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Profile,
		[System.String]
		[Parameter(Position=3)]
		$Network,
		[System.Boolean]
		[Parameter(Position=4)]
		$PXE
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			if ($PXE) {$PXEtxt = "PXE=enabled"} Else {$PXEtxt = ""}
			$subject = start-plink $Cred $Chassis "add enet-connection $profile Network=$Network $PXEtxt"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCenetconnection  {
<#
	.SYNOPSIS
		set an existing ethernet connection for a given blade chassis.
		
		Added by CoStar

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the blade chassis and set an ethernet connection to a profile.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the username and password to connect to the chassis VC manager.
		
	.PARAMETER  Profile
		This is the profile which you want to make ethernet changes to.
		
	.PARAMETER  Port
		This is the profile port which you want to make ethernet changes to.

	.EXAMPLE
		PS C:\> set-HPVCenetconnection -Chassis 'chassis1' -Credentials $cred -Profile 'Bay1' -port 4 -network 'MyEthernetNetwork'
		This example shows how to call the Remove-HPVCenetconnection function with named parameters.

	.INPUTS
		System.String,PSCredential,System.String

	.OUTPUTS
		

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1, Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		[System.String]
		[Parameter(Position=2, Mandatory=$true, ValueFromPipeline=$false)]
		$Profile,
		[int]
		[Parameter(Position=3, Mandatory=$true, ValueFromPipeline=$false)]
		$port,
		[System.String]
		[Parameter(Position=4, Mandatory=$true, ValueFromPipeline=$false)]
		$Network,
		[System.String]
		[Parameter(Position=5, Mandatory=$true, ValueFromPipeline=$false)]
		$speedType,
		[int]
		[Parameter(Position=6, Mandatory=$true, ValueFromPipeline=$false)]
		$speed
		
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			Write-Host "CMD: set enet-connection $profile $port Network=$Network SpeedType=Custom speed=$speed"
			$subject = start-plink $Cred $Chassis "set enet-connection $profile $port Network=$Network SpeedType=Custom speed=$speed"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		
		Write-Output $subject
		}
		catch {
		}
	}
}


#EndRegion

#Region Ethernet VLAN Functions
function Get-HPVCEnetVLAN  {
<#
	.SYNOPSIS
		Gets the Ethernet VLAN configuration settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the ethernet VLAN configuration as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCEnetVLAN -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCEnetVLAN 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCEnetVLAN

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Enet-VLAN -output=script2'
			$EnetVLAN = New-Object "HPVCEnetVLAN"
			[HPVCEnetVLAN[]] $array = @()
			$EnetVLAN.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				$EnetVLAN.VLANTagControl, $EnetVLAN.SharedServerVLANID, $EnetVLAN.PreferredSpeed, $EnetVLAN.MaxSpeed  = $subject[$i] -split ";"
				
				$array += $EnetVLAN
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCVLANTagControl  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$VLANTagControl
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set enet-vlan VLANTagControl=$VLANTagControl"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCSharedServerVLANID  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$SharedServerVLANID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set enet-vlan SharedServerVLANID=$SharedServerVLANID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Add-HPVCServerPortMapRange  {
	# Added by CoStar
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[System.String]
		$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		# The ID of an existing Ethernet connection associated with a profile and a server port. The format of the ConnectionID is <ProfileName:PortNumber>
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$ConnectionId,
		# The name of the shared uplink set to use with the server port mapping
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$UplinkSet,
		# The VLAN IDs to use for the mapping. The format is a comma-separated list of VLAN ID ranges, where a range is either a single VLAN ID or a hyphen-separated pair of VLAN IDs that identify a range of VLAN IDs. Valid VLAN ID values include 1 to 4094. 
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$VlanIds
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
			Write-Host "CMD: add server-port-map-range $ConnectionId UplinkSet=$UplinkSet VLanIds=$VlanIds" -ForegroundColor Yellow
			
			$subject = start-plink $Cred $Chassis "add server-port-map-range $ConnectionId UplinkSet=$UplinkSet VLanIds=$VlanIds"
			write-output $subject
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCServerPortMapRange  {
	# Added by CoStar
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[System.String]
		$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		# The ID of an existing Ethernet connection associated with a profile and a server port. The format of the ConnectionID is <ProfileName:PortNumber>
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$ConnectionId,
		# The VLAN IDs to use for the un-mapping. The format is a comma-separated list of VLAN ID ranges, where a range is either a single VLAN ID or a hyphen-separated pair of VLAN IDs that identify a range of VLAN IDs. Valid VLAN ID values include 1 to 4094. 
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$VlanIds
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove server-port-map-range $ConnectionId vlanids=$VlanIds"
			write-output $subject
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Add-HPVCServerPortMap  {
	# Added by CoStar - Adds a server-port-map to a connectionID
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[System.String]
		$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		# The ID of an existing Ethernet connection associated with a profile and a server port. The format of the ConnectionID is <ProfileName:PortNumber>
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$ConnectionId,
		# The name of the Ethernet Network to add (like INT-ISCSI-DEVTST-02-4)
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$EthernetNetwork,
		# The VLAN ID to use for the mapping. The format is a single VLAN ID integer
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$VlanId
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			
			Write-Host "CMD: add server-port-map $ConnectionId $EthernetNetwork VLanID=$VlanId UnTagged=true" -ForegroundColor Yellow
			
			$subject = start-plink $Cred $Chassis "add server-port-map $ConnectionId $EthernetNetwork VLanID=$VlanId UnTagged=true"
			write-output $subject
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCServerPortMap  {
	# Added by CoStar - removes a server-port-map to a connectionID
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[System.String]
		$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		# The ID of an existing Ethernet connection associated with a profile and a server port. The format of the ConnectionID is <ProfileName:PortNumber>
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$ConnectionId,
		# The name of the Ethernet Network to remove (like INT-ISCSI-DEVTST-02-4)
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$EthernetNetwork
	)
	begin {
		try {
			if ($ConnectionId -eq $null)	{
				Write-Error "ConnectionId can't be null"
			}
			if ($ConnectionId -eq "*")	{
				Write-Error "ConnectionId can't be *, that will remove all server-port-map configurations from the domain"
			}
			if (! $ConnectionId)	{
				Write-Error "ConnectionId can't be null"
			}
		}
		catch {
		}
	}
	process {
		try {
			# remove server-port-map <ConnectionID|*> [<Network Name>]
			Write-Host "CMD: remove server-port-map $ConnectionId $EthernetNetwork" -ForegroundColor Yellow
			
			$subject = start-plink $Cred $Chassis "remove server-port-map $ConnectionId $EthernetNetwork"
			write-output $subject
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


#EndRegion

#Region Interconnect Functions
function Get-HPVCInterconnect  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Interconnect settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Interconnect settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCInterconnect -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCInterconnect 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCInterconnect

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Interconnect * -output=script2'
			$Interconnect = New-Object "HPVCInterconnect"
			[HPVCInterconnect[]] $array = @()
			$Interconnect.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$Interconnect.ID, $Interconnect.Enclosure, $Interconnect.Bay, $Interconnect.Type, $Interconnect.ProductName, $Interconnect.Status, $Interconnect.CommStatus, `
				$Interconnect.OAStatus, $Interconnect.PowerState, $Interconnect.MACAddress, $Interconnect.FirmwareVersion, $Interconnect.Manufacturer, `
				$Interconnect.PartNumber, $Interconnect.SparePartNumber, $Interconnect.RackName, $Interconnect.SerialNumber, $Interconnect.UID = $subject[$i] -split ";"

				$array += $Interconnect
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCInterconnect  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ModuleID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove interconnect $ModuleID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCAllInterconnect  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ModuleID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove interconnect *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


#EndRegion

#Region Ldap Functions
function Get-HPVCLdap  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Ldap settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Ldap settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCLdap -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCLdap 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCLdap

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Ldap -output=script2'
			$Ldap = New-Object "HPVCLdap"
			[HPVCLdap[]] $array = @()
			$Ldap.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$Ldap.Enabled, $Ldap.LocalUsers, $Ldap.NTAccountMapping, $Ldap.ServerAddress, $Ldap.SSLPort, $Ldap.SearchContext1, $Ldap.SearchContext2, $Ldap.SearchContext3 = $subject[$i] -split ";"

				$array += $Ldap
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCLdap  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set Ldap $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}




#EndRegion

#Region LdapGroup Functions
function Get-HPVCLdapGroup  {
<#
	.SYNOPSIS
		Gets the Virtual Connect LdapGroup settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the LdapGroup settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCLdapGroup -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCLdapGroup 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCLdapGroup

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Ldap-Group * -output=script2'
			$LdapGroup = New-Object "HPVCLdapGroup"
			[HPVCLdapGroup[]] $array = @()
			$LdapGroup.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$LdapGroup.Name, $LdapGroup.Privileges, $LdapGroup.Description = $subject[$i] -split ";"

				$array += $LdapGroup
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCLdapGroup  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$GroupName,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set Ldap-Group $GroupName $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Add-HPVCLdapGroup  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$GroupName,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add Ldap-Group $GroupName $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCLdapGroup  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$GroupName
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove Ldap-Group $GroupName"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Remove-HPVCAllLdapGroup  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove Ldap-Group *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region MacCache Functions
function Get-HPVCMacCache  {
<#
	.SYNOPSIS
		Gets the Virtual Connect MacCache settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the MacCache settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCMacCache -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCMacCache 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCMacCache

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Mac-Cache -output=script2'
			$MacCache = New-Object "HPVCMacCache"
			[HPVCMacCache[]] $array = @()
			$MacCache.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$MacCache.Enabled, $MacCache.RefreshInterval = $subject[$i] -split ";"

				$array += $MacCache
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCMacCache  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set Mac-Cache $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region Profile Functions
function Get-HPVCProfile  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Profile settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Profile settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCProfile -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCProfile 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCProfile

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Profile -output=script2'
			$Profile = New-Object "HPVCProfile"
			[HPVCProfile[]] $array = @()
			$Profile.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$Profile.Name, $Profile.DeviceBay, $Profile.Server, $Profile.Status = $subject[$i] -split ";"

				$array += $Profile
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Set-HPVCProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ProfileName,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set Profile $ProfileName $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Add-HPVCProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ProfileName,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add Profile $ProfileName $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Mount-HPVCProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ProfileName,
		[Parameter(Position=3)]
		$DeviceBay
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "assign Profile $ProfileName $DeviceBay"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Dismount-HPVCProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ProfileName
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "unassign Profile $ProfileName"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Remove-HPVCProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ProfileName
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove profile $ProfileName"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Remove-HPVCAllProfile  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove Profile *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
#EndRegion

#Region Server Functions
function Get-HPVCServer  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Server settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Server settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCServer -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCServer 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCServer

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Server * -output=script2'
			$Server = New-Object "HPVCServer"
			[HPVCServer[]] $array = @()
			$Server.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i += 3) {
				
				$Server.ServerID, $Server.EnclosureName, $Server.EnclosureID, $Server.Bay, $Server.Description, $Server.Status, $Server.Power, `
				$Server.UID, $Server.ServerProfile, $Server.Height, $Server.Width, $Server.PartNumber, $Server.SerialNumber, $Server.ServerName, `
				$Server.OSName, $Server.AssetTag, $Server.ROMVersion, $Server.Memory = $subject[$i] -split ";"

				$array += $Server
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Start-HPVCServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ServerID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "poweron Server $ServerID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Stop-HPVCServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ServerID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "poweroff Server $ServerID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Restart-HPVCServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$ServerID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "reboot Server $ServerID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Start-HPVCAllServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "poweron Server *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Stop-HPVCAllServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "poweroff Server *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Restart-HPVCAllServer  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "reboot Server *"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
<#
.SYNOPSIS
find-blade Gives you the blade ethernet information so you can commands like adding a vlan

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
$chassisRules = @{
		'RESTON, VA' = @{
					'2' = '192.168.32.209';# 	4.10
					'3' = '192.168.32.213';# 	4.10
					'4' = '192.168.32.212';# 	4.10
					'5' = '192.168.32.126';#	3.75
					'6' = '192.168.32.190';#	3.7
					'7' = '192.168.32.202';#	3.51
					'8' = '192.168.32.204';# 	3.51
				}
		'VIENNA, VA' = @{
					'1' = '192.168.28.14';
					'2' = '192.168.28.16';
					'3' = '192.168.28.18';
				}
		'PALOALTO, PA' = @{
					'1' = '192.168.26.110';
					'2' = '192.168.26.111';
				}
	}
write-host "Loading HP Virtual Connect Module" -ForegroundColor Green
Import-Module "\\dcfile1\systems\scripts\Modules\hp-virtualconnect\hp-virtualconnect.psm1" -Force
$CRED = get-credential
$bladeEnet = find-blade -computer DCVMHPRD110 -site 'Reston, VA'  -chassisrules $chassisrules -cred $cred

#>
function find-blade {
[CmdletBinding(supportsshouldprocess=$True)]
param(
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$computer,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[string]$site,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[hashtable]$chassisRules,
	[parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	$Cred
)

	BEGIN
	{
	

	}
	PROCESS	
	{
		
		foreach ($chassisMap in $($chassisRules.$site.Getenumerator())  )	{
			Write-host "Looking for VC blade profile $computer in chassis $($ChassisMap.Value)"
			$vcServerProfiles = Get-HPVCServer -Chassis $chassisMap.Value -CRED $CRED
			if ( ($vcServerProfiles | select ServerProfile) -match $computer) {
				Write-host "Found blade $computer in chassis $($chassisMap.Value)"
				$chassis =  $chassisMap.Value
				break
			}
		}
		
		IF (test-path variable:chassis)	{
			sleep 5 # there might be  race condition while login directly after Get-HPVCServer
			$bladeEnet = Get-HPVCEnetConnection -Chassis $chassis -Cred $cred | ? {( ($_.Profile -eq $computer ) ) }
			Write-Output $bladeEnet
		}
	}

	END
	{

	}	

}
#EndRegion

#Region Server Port Functions
function Get-HPVCServerPort  {
<#
	.SYNOPSIS
		Gets the Virtual Connect ServerPort settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the ServerPort settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCServerPort -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCServerPort 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCServerPort

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Server-Port * -output=script2'
			$ServerPort = New-Object "HPVCServerPort"
			[HPVCServerPort[]] $array = @()
			$ServerPort.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i += 3) {
				
				$ServerPort.Port, $ServerPort.Server, $ServerPort.IOModule, $ServerPort.AdapterType, $ServerPort.ID, $ServerPort.Profile = $subject[$i] -split ";"

				$array += $ServerPort
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region SNMP Functions
function Get-HPVCSNMP  {
<#
	.SYNOPSIS
		Gets the Virtual Connect SNMP settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the SNMP settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCSNMP -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCSNMP 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCSNMP

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show SNMP * -output=script2'
			$SNMP = New-Object "HPVCSNMP"
			[HPVCSNMP[]] $array = @()
			$SNMP.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$SNMP.Type, $Snmp.Enabled, $Snmp.CommunityName, $Snmp.SystemContact, $Snmp.SMISEnabled = $subject[$i] -split ";"

				$array += $SNMP
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Set-HPVCSNMP  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set snmp $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region Stacking Link Functions
function Get-HPVCStackingLink  {
<#
	.SYNOPSIS
		Gets the Virtual Connect StackingLink settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the StackingLink settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCStackingLink -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCStackingLink 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCStackingLink

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show stackinglink -output=script2'
			$StackingLink = New-Object "HPVCStackingLink"
			[HPVCStackingLink[]] $array = @()
			$StackingLink.Chassis = $Chassis
			for ($i = 4; $i -lt $subject.count; $i ++) {
				
				$StackingLink.Link, $Stackinglink.Speed, $Stackinglink.ConnectedFrom, $Stackinglink.ConnectedTo = $subject[$i] -split ";"

				$array += $StackingLink
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Get-HPVCStackingLinkStatus  {
<#
	.SYNOPSIS
		Gets the Virtual Connect StackingLinkStatus settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the StackingLinkStatus settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCStackingLinkStatus -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCStackingLinkStatus 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCStackingLinkStatus

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show StackingLink -output=script2'
			$StackingLinkStatus = New-Object "HPVCStackingLinkStatus"
			[HPVCStackingLinkStatus[]] $array = @()
			$StackingLinkStatus.Chassis = $Chassis
			for ($i = 1; $i -lt 2; $i++) {
				
				$StackingLinkStatus.ConnectionStatus, $Stackinglinkstatus.RedundancyStatus = $subject[$i] -split ";"

				$array += $StackingLinkStatus
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
#EndRegion

#Region Status Functions
function Get-HPVCStatus  {
<#
	.SYNOPSIS
		Gets the Virtual Connect Status settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the Status settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCStatus -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCStatus 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCStatus

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show Status -output=script2'
			$Status = New-Object "HPVCStatus"
			[HPVCStatus[]] $array = @()
			$Status.Chassis = $Chassis
			$Status.OverallDomainStatus = $subject[1]
			for ($i = 3; $i -lt 4; $i ++) {
				
				$Status.Critical, $Status.Major, $Status.Minor, $Status.Warning, $Status.Information, $Status.Unknown = $subject[$i] -split ";"

				$array += $Status
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Export-HPVCSupportInfo  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$Address
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "save supportinfo address=$address"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Reset-HPVC  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		[switch] $Failover
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			if ($Failover) {$subject = start-plink $Cred $Chassis "reset vcm -failover"}
			else {$subject = start-plink $Cred $Chassis "reset vcm"}
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Get-HPVCVersion  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "show version"
			$Version = New-Object "HPVCVersion"
			[HPVCVersion[]] $array = @()
			$Version.Chassis = $Chassis
			for ($i = 0; $i -lt 1; $i ++) {
				
				$Version.Version  = $subject[0]

				$array += $Version
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

#EndRegion

#Region SystemLog Functions
function Get-HPVCSystemLog  {
<#
	.SYNOPSIS
		Gets the Virtual Connect SystemLog settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the SystemLog settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCSystemLog -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCSystemLog 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCSystemLog

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show SystemLog -output=script2'
			$SystemLog = New-Object "HPVCSystemLog"
			[HPVCSystemLog[]] $array = @()
			$SystemLog.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i ++) {
				
				$SystemLog.Record, $SystemLog.DateTime, $SystemLog.Info, $SystemLog.Message = $subject[$i] -split ";"
				if ($SystemLog.Record -ne "Record") {
					$array += $SystemLog
				}
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


#EndRegion

#Region UplinkPort Functions
function Get-HPVCUplinkPort  {
<#
	.SYNOPSIS
		Gets the Virtual Connect UplinkPort settings.

	.DESCRIPTION
		Uses the Putty Plink executable to SSH into the virtual connect and retrieve the UplinkPort settings as .net objects.

	.PARAMETER  Chassis
		The IP Address of DNS name of the blade chassis virtual connect. This parameter can be passed on the pipeline.

	.PARAMETER  Credentials
		This is a PSCredentials object that contains the name and password to connect to the chassis VC manager.

	.EXAMPLE
		PS C:\> Get-HPVCUplinkPort -Chassis 'chassis1' -Credentials $cred
		This example shows how to call the function with named parameters.

	.EXAMPLE
		PS C:\> Get-HPVCUplinkPort 'chassis1' $cred
		This example shows how to call the with positional parameters.

	.INPUTS
		System.String,PSCredential

	.OUTPUTS
		HPVCUplinkPort

#>
	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis 'show UplinkPort * -output=script2'
			$UplinkPort = New-Object "HPVCUplinkPort"
			[HPVCUplinkPort[]] $array = @()
			$UplinkPort.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$UplinkPort.ID, $Uplinkport.Enclosure, $Uplinkport.Status, $Uplinkport.Type, $Uplinkport.Speed, $Uplinkport.UsedBy, $Uplinkport.ConnectedFrom, $Uplinkport.ConnectedTo = $subject[$i] -split ";"

				$array += $UplinkPort
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Set-HPVCUplinkPort  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$PortID,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "set UplinkPort $PortID $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}
function Add-HPVCUplinkPort  {

	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		[System.String]
		$Chassis,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Cred,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$PortID,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Property,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$UplinkSet,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
		$Speed
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "add UplinkPort $PortID UplinkSet=$UplinkSet Speed=$Speed"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}


function Remove-HPVCUplinkPort  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$PortID,
		[Parameter(Position=3)]
		$Property
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "remove UplinkPort $PortID $Property"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Show-HPVCStatistic  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$PortID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "show statistics $PortID -output=script2"
			$Statistic = New-Object "HPVCStatistic"
			[HPVCStatistic[]] $array = @()
			$Statistic.Chassis = $Chassis
			for ($i = 1; $i -lt $subject.count; $i++) {
				
				$Statistic.Name, $Statistic.Value = $subject[$i] -split ";"

				$array += $Statistic
			} 
			$array
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}

function Reset-HPVCStatistic  {

	[CmdletBinding()]
	param(
		[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
		[System.String]
		$Chassis,
		[Parameter(Position=1)]
		$Cred,
		[Parameter(Position=2)]
		$PortID
	)
	begin {
		try {
		}
		catch {
		}
	}
	process {
		try {
			$subject = start-plink $Cred $Chassis "reset statistics $PortID"
		}
		catch {Write-Host $_.Exception.ToString() 
		}
	}
	end {
		try {
		}
		catch {
		}
	}
}