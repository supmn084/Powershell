#Requires -Version 4

<#
.SYNOPSIS
This module holds all the necessary functions for creating Costar Group accounts

.NOTES

FIXLIST

1.2
- Employee Accounts

1.1
- UK and Apts Integration

1.0
- Service Accounts
- Resource Mailboxes


OUTSTANDING ISSUES

- Might need to check for account that might have email address conflicts in Test-CGAccountName
- Trim spaces and make the alias lowercase in the MailboxEnable function

#>
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"

if (!(Get-Module ActiveDirectory))
{
	## Or check for the cmdlets you need
	## Load it nested, and we'll automatically remove it during clean up
	import-module ActiveDirectory
}

[xml]$config = Get-Content \\dcfile1\systems\scripts\Modules\csgp-UserProvisioning\config.xml
#Export-ModuleMember -Variable $config



<#
	.SYNOPSIS
		A brief description of the Test-CGAccountName function.
	
	.DESCRIPTION
		A detailed description of the Test-CGAccountName function.
	
	.PARAMETER User
		A description of the User parameter.
	
	.EXAMPLE
		PS C:\> Test-CGAccountName -PipelineVariable $value1 -User $value2
	
	.NOTES
		OUTSTANDING ISSUES
		- need to add VP to forest list once FW rules are clear
#>
function Test-CGAccountName
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$User,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[switch]$OverrideDC,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[string]$Server
	)
	
	
	begin
	{
		$ForestList = @("costar.local", "corp.virtualpremise.com")
		$UserExists = $false
	}
	process
	{
		foreach ($Forest in $ForestList)
		{
			$GC = (Get-ADForest $Forest).DomainNamingMaster
			$SearchBase = (Get-ADDomain (Get-ADForest $Forest).RootDomain).DistinguishedName
			Write-Verbose "Querying Server: ${GC}:3268 with SearchBase:${SearchBase}"
			$Record = Get-ADObject -Filter { samAccountName -eq $User } -SearchBase $SearchBase -SearchScope SubTree -Server ${GC}':3268'
			if ($Record)
			{
				Write-Verbose "Found Account for $($Record.Name) with userid: $($Record.SamAccountName) and DistinguishedName: $($Record.DistinguishedName) "
				$UserExists = $true
				return
			}
		}
		if ($OverrideDC)
		{
			$GC = $Server
			$DomainString = $Server.SubString((($Server.split(".")[0]).Length) + 1)
			$SearchBase = (Get-ADDomain $DomainString).DistinguishedName
			Write-Verbose "Querying Server: ${GC}:3268 with SearchBase:${SearchBase}"
			$Record = Get-ADObject -Filter { samAccountName -eq $User } -SearchBase $SearchBase -SearchScope SubTree -Server ${GC}:3268
			if ($Record)
			{
				Write-Verbose "Found Account for $($Record.Name) with userid: $($Record.SamAccountName) and DistinguishedName: $($Record.DistinguishedName) "
				$UserExists = $true
				return
			}
		}
	}
	end
	{
		Write-Output $UserExists
	}
}
Export-ModuleMember -Function Test-CGAccountName

<#
	.SYNOPSIS
		A brief description of the New-CGPassword function.
	
	.DESCRIPTION
		A detailed description of the New-CGPassword function.
	
	.PARAMETER Lower
		A description of the Lower parameter.
	
	.PARAMETER Numeric
		A description of the Numeric parameter.
	
	.PARAMETER Special
		A description of the Special parameter.
	
	.PARAMETER Total
		A description of the Total parameter.
	
	.PARAMETER Upper
		A description of the Upper parameter.
	
	.EXAMPLE
		PS C:\> New-CGPassword -Lower $value1 -Numeric $value2
	
	.NOTES
		Pass this to ConvertTo-SecureString to abstract the password generated
#>
function New-CGPassword
{
	[CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
	param (
		[parameter(Mandatory = $true, Position = 0)]
		[ValidateRange(4, ([int]::MaxValue))]
		[int]$Total = 16,
		[ValidateRange(0, ([int]::MaxValue))]
		[int]$Upper = 1,
		[ValidateRange(0, ([int]::MaxValue))]
		[int]$Lower = 1,
		[ValidateRange(0, ([int]::MaxValue))]
		[int]$Special = 1,
		[ValidateRange(0, ([int]::MaxValue))]
		[int]$Numeric = 1
	)
	Process
	{
		if (($Upper + $Lower + $Numeric + $Special) -gt $Total)
		{
			throw "New-Password : Cannot validate argument on parameter 'Total'. The $Total argument is less than the sum of parameters 'Upper','Lower' and 'Numeric'. 
    Supply an argument that is greater than or equal to the sum of parameters 'Upper','Lower' and 'Numeric'."
		}
		
		[int[]]$IArr = New-Object System.Int32
		If ($Upper -gt 0)
		{
			$IArr += Get-Random -Input $(65..90) -Count $Upper
		}
		If ($Lower -gt 0)
		{
			$IArr += Get-Random -Input $(97..122) -Count $Lower
		}
		If ($Numeric -gt 0)
		{
			$IArr += Get-Random -Input $(48..57) -Count $Numeric
		}
		If ($Special -gt 0)
		{
			$IArr += Get-Random -Input $(33, 35, 36, 38, 40, 41, 43, 45, 46) -Count $Special
		}
		If ($Total -gt ($Upper + $Lower + $Numeric + $Special))
		{
			$IArr += Get-Random -Input $(33, 35, 36, 38, 40, 41, 43, 45, 46 + 48..57 + 65..90 + 97..122) -Count ($Total - $Upper - $Lower - $Numeric)
		}
		$IArr = $IArr -ne 0
		return ([char[]](Get-Random -InputObject $IArr -Count $IArr.Count)) -join ""
	}
}
Export-ModuleMember -Function New-CGPassword

<#
	.SYNOPSIS
		A brief description of the Get-CGOUPath function.
	
	.DESCRIPTION
		A detailed description of the Get-CGOUPath function.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.PARAMETER Organization
		A description of the Organization parameter.
	
	.PARAMETER Type
		A description of the Type parameter.
	
	.EXAMPLE
		PS C:\> Get-CGOUPath -Department 'Value1' -Domain 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Get-CGOUPath
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$Domain,
		[Parameter(Mandatory = $true)]
		[System.String]$Organization,
		[Parameter(Mandatory = $true)]
		[System.String]$Department,
		[Parameter(Mandatory = $true)]
		[System.String]$Type
	)
	
	try
	{
		$FinalOUPath = $null
		switch ($Type)
		{
			"Service" {
				$FinalOUPath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.ServiceDN
			}
			"ManagedService" {
				$FinalOUPath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.ServiceDN
			}
			"SharedMailbox" {
				$FinalOUPath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.ResourceDN
			}
			"SharedMailboxRAGroup" {
				$FinalOUPath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.mailResourceAccessDN
			}
			"SharedMailboxRoleGroup" {
				$FinalOUPath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.mailRoleDN
			}
			"Employee"
			{
				$OUpath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.EmployeeDN
				$FinalOUPath = "OU=$Department,$OUpath"
			}
			"Contractor"
			{
				$OUpath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.EmployeeDN
				$FinalOUPath = "OU=Contractors,OU=$Department,$OUpath"
			}
			default
			{
				$OUpath = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.EmployeeDN
				$FinalOUPath = "OU=$Department,$OUpath"
			}
		}
		Write-Verbose "Testing if $FinalOUPath Exists"
		$DC = Get-ADDomainController -Discover -Service ADWS -DomainName $Domain | Select -ExpandProperty HostName
		$tempOU = Get-ADOrganizationalUnit -Identity $FinalOUPath -Server $DC
		
	}
	catch
	{
		Write-Verbose "Setting $FinalOUPath to NULL"
		$FinalOUPath = $null
	}
	
	Write-Output $FinalOUPath
	
}
Export-ModuleMember -Function Get-CGOUPath

<#
	.SYNOPSIS
		A brief description of the Get-CGAcctAttributes function.
	
	.DESCRIPTION
		A detailed description of the Get-CGAcctAttributes function.
	
	.PARAMETER Type
		A description of the Type parameter.
	
	.EXAMPLE
		PS C:\> Get-CGAcctAttributes -PipelineVariable $value1 -Type 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Get-CGAcctAttributes
{
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, Mandatory = $true)]
		[System.String]$Type
	)
	
	try
	{
		switch ($Type)
		{
			"Service" {
				Write-Output @{ "extensionattribute4" = "Service"; "info" = "Created on $Date by $CreatedBy" }
			}
			"ManagedService" {
				Write-Output @{ "extensionattribute4" = "Service"; "info" = "Created on $Date by $CreatedBy" }
			}
			"SharedMailbox" {
				Write-Output @{ "extensionattribute4" = "Resource"; "info" = "Created on $Date by $CreatedBy" }
			}
			"Employee" {
				Write-Output @{ "extensionattribute4" = "Employee"; "info" = "Created on $Date by $CreatedBy" }
			}
			"Contractor" {
				Write-Output @{ "extensionattribute4" = "Contractor"; "info" = "Created on $Date by $CreatedBy" }
			}
			default
			{
				Write-Output @{ "extensionattribute4" = "Resource"; "info" = "Created on $Date by $CreatedBy" }
			}
		}
	}
	catch
	{
		Write-Error "uhoh!"
	}
	
}
#Export-ModuleMember -Function Get-CGAcctAttributes

<#
	.SYNOPSIS
		A brief description of the New-CGMailbox function.
	
	.DESCRIPTION
		A detailed description of the New-CGMailbox function.
	
	.PARAMETER Name
		A description of the Name parameter.
	
	.PARAMETER ActiveSyncEnabled
		A description of the ActiveSyncEnabled parameter.

	.PARAMETER Shared
		A description of the ActiveSyncEnabled parameter.
	
	.PARAMETER Domain
		A description of the ActiveSyncEnabled parameter.
	
	.PARAMETER DomainController
		A description of the ActiveSyncEnabled parameter.

	.EXAMPLE
		Example of the function
	
	.NOTES
		Done

#>
function New-CGMailbox
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$Name,
		[Parameter(Mandatory = $false)]
		[boolean]$Shared = $false,
		[Parameter(Mandatory = $false)]
		[boolean]$ActiveSyncEnabled = $false,
		[Parameter(Mandatory = $true)]
		[System.String]$Domain,
		[Parameter(Mandatory = $false)]
		[System.String]$DomainController = "dcus2.us.costar.local"
		
	)
	begin
	{
		try
		{
			$ExchSession = New-CGExchangeSession -Domain $Domain
			Write-Verbose "Got Exchange Remote Session"
		}
		catch
		{
			Write-Error "Could not get Exchange Remote Session"
		}
		
	}
	process
	{
		try
		{
			Write-Verbose -Message "Creating mailbox for user... $Name on $DomainController"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$DC) Enable-Mailbox -Identity $Username -Alias $Username -DomainController $DC
			} -ArgumentList ($Name, $DomainController) | Out-Null
			Write-Verbose -Message "Disabling POP3 for user... $Name on $DomainController"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$DC) Set-CASMailbox $UserName -PopEnabled $false -DomainController $DC
			} -ArgumentList ($Name, $DomainController)
			Write-Verbose -Message "Disabling ActiveSync for user... $Name on $DomainController"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$ActiveSync,
					$DC) Set-CASMailbox $UserName -ActiveSyncEnabled $ActiveSync -DomainController $DC
			} -ArgumentList ($Name, $ActiveSyncEnabled, $DomainController)
			Write-Verbose -Message "Setting Message Size Limits... $Name on $DomainController"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$DC) Set-Mailbox $UserName -MaxSendSize 80MB -MaxReceiveSize 80MB -DomainController $DC
			} -ArgumentList ($Name, $DomainController)
			If ($Shared)
			{
				Write-Verbose -Message "Set $Name as Shared Mailbox"
				Invoke-Command -Session $ExchSession {
					param ($UserName,
						$DC) Set-Mailbox $UserName -Type Shared -DomainController $DC
				} -ArgumentList ($Name, $DomainController)
			}
		}
		catch
		{
			Write-Error "New-CGMailbox: We done messed up`n"
			Write-Error $_.Exception.Message
		}
	}
	end
	{
		try
		{
			Remove-PSSession -Session $ExchSession
		}
		catch
		{
			Write-Error "Exchange Remote Session might still be open"
		}
	}
}
Export-ModuleMember -Function New-CGMailbox

<#
	.SYNOPSIS
		A brief description of the New-CGServiceAccount function.
	
	.DESCRIPTION
		A detailed description of the New-CGServiceAccount function.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.PARAMETER Description
		A description of the Description parameter.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.PARAMETER Name
		A description of the Name parameter.
	
	.PARAMETER Organization
		A description of the Organization parameter.
	
	.EXAMPLE
		PS C:\> New-CGServiceAccount -Department 'Value1' -Description 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function New-CGServiceAccount
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateLength(1, 20)]
		[string]$Name,
		[parameter(Mandatory = $true)]
		[string]$Domain,
		[parameter(Mandatory = $true)]
		[string]$Organization,
		[parameter(Mandatory = $true)]
		[string]$Description,
		[parameter(Mandatory = $true)]
		[string]$Department
		
	)
	
	begin
	{
		$Date = Get-Date -Format MM-dd-yyyy
		$CreatedBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
		$Type = "Service"
		$CannotChangePassword = $true
		$PasswordNeverExpires = $true
		$ChangePasswordAtLogon = $false
		$Prefix = 'svc'
		
		Test-Domain -Domain $Domain
		Test-Department -Department $Department
		Test-Organization -Domain $Domain -Organization $Organization
		
	}
	process
	{
		$OUPath = Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type $Type
		if ($OUPath -eq $null)
		{
			Write-Error "Invalid OU"
		}
		
		$UPNsuffix = "@$((Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']").node.DNSSuffix)"
		$OrgName = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.fullName
		$Attributes = Get-CGAcctAttributes -Type $Type
		$Password = New-CGPassword -Total 16
		$AccountPassword = (ConvertTo-SecureString $Password -AsPlainText -Force)
		$DC = Get-ADDomainController -Discover -Service ADWS -DomainName $Domain | Select -ExpandProperty HostName
		$Name = $Name -replace " ", ""
		
		if ($Name.ToLower().Startswith($Prefix))
		{
			if ((Test-CGAccountName -User $Name) -eq $false)
			{
				Write-Verbose "Creating $Type Account: $Name at $OUPath"
				New-ADUser -Name $Name -DisplayName $Name -AccountPassword $AccountPassword -CannotChangePassword $CannotChangePassword -ChangePasswordAtLogon $ChangePasswordAtLogon -Company $OrgName -Department $Department -Description $Description -OtherAttributes $Attributes -PasswordNeverExpires $PasswordNeverExpires -Path $OUPath -UserPrincipalName "${Name}${UPNsuffix}" -Enabled $true -Server $DC
				Write-Output "Account $Domain\$Name was successfully created"
				Write-Output "Password is: $Password"
				Write-Output "If this is a service account please remember to store the password in the appropriate Password Safe database"
			}
			else
			{
				Write-Error "Account already exists"
			}
		}
		else
		{
			Write-Error "Account name does not start with $Prefix"
		}
	}
	end
	{
		
	}
}
Export-ModuleMember -Function New-CGServiceAccount

<#
	.SYNOPSIS
		A brief description of the New-CGSharedMailbox function.
	
	.DESCRIPTION
		A detailed description of the New-CGSharedMailbox function.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.PARAMETER Description
		A description of the Description parameter.
	
	.PARAMETER DisplayName
		A description of the DisplayName parameter.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.PARAMETER Name
		A description of the Name parameter.
	
	.PARAMETER Organization
		A description of the Organization parameter.
	
	.PARAMETER PipelineVariable
		A description of the PipelineVariable parameter.
	
	.EXAMPLE
		PS C:\> New-CGSharedMailbox -Department 'Value1' -Description 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function New-CGSharedMailbox
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateLength(1, 20)]
		[string]$Name,
		[parameter(Mandatory = $true)]
		[string]$Domain,
		[parameter(Mandatory = $true)]
		[string]$Organization,
		[parameter(Mandatory = $true)]
		[string]$Description,
		[parameter(Mandatory = $true)]
		[string]$Department,
		[parameter(Mandatory = $true)]
		[string]$DisplayName
	)
	
	begin
	{
		$Date = Get-Date -Format MM-dd-yyyy
		$CreatedBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
		$Type = "SharedMailbox"
		$CannotChangePassword = $true
		$PasswordNeverExpires = $true
		$ChangePasswordAtLogon = $false
		
		Test-Domain -Domain $Domain
		Test-Department -Department $Department
		Test-Organization -Domain $Domain -Organization $Organization
		
		try
		{
			$ExchSession = New-CGExchangeSession -Domain $Domain
			Write-Verbose "Got Exchange Remote Session"
		}
		catch
		{
			Write-Error "Could not get Exchange Remote Session"
		}
		
	}
	process
	{
		
		$OUPath = Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type $Type
		if ($OUPath -eq $null)
		{
			Write-Error "Invalid OU"
		}
		$UPNsuffix = "@$((Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']").node.DNSSuffix)"
		$OrgName = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.fullName
		$Attributes = Get-CGAcctAttributes -Type $Type
		$Password = New-CGPassword -Total 16
		$AccountPassword = (ConvertTo-SecureString $Password -AsPlainText -Force)
		$DC = Get-ADDomainController -Discover -Service ADWS -DomainName $Domain | Select -ExpandProperty HostName
		$Name = ($Name -replace " ", "").tolower()
		
		if ((Test-CGAccountName -User $Name) -eq $false)
		{
			Write-Verbose "Creating $Type Account: $Name at $OUPath"
			New-ADUser -Name $Name -DisplayName $DisplayName -AccountPassword $AccountPassword -CannotChangePassword $CannotChangePassword -ChangePasswordAtLogon $ChangePasswordAtLogon -Company $OrgName -Department $Department -Description $Description -OtherAttributes $Attributes -PasswordNeverExpires $PasswordNeverExpires -Path $OUPath -UserPrincipalName "${Name}${UPNsuffix}" -Enabled $true -Server $DC
			Write-Output "Account $Domain\$Name was successfully created"
			New-CGMailbox -Name $Name -Shared $true -Domain $Domain -DomainController $DC
			$MailboxUser = (Get-ADUser -Server $DC -Identity $Name | select DistinguishedName).DistinguishedName
			$FullAccessRoleGroup = "${Name}_Full"
			$FullAccessRAGroup = "MBX_$FullAccessRoleGroup"
			$SendAsRoleGroup = "${Name}_SendAs"
			$SendAsRAGroup = "MBX_$SendAsRoleGroup"
			
			if ((Test-CGAccountName -User $FullAccessRAGroup) -eq $false)
			{
				New-ADGroup -Name $FullAccessRAGroup -Description "Resource Access Group for Full Access to Mailbox $Name" -DisplayName $FullAccessRAGroup -GroupCategory Security -GroupScope DomainLocal -Server $DC -Path (Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type "SharedMailboxRAGroup")
			}
			if ((Test-CGAccountName -User $FullAccessRoleGroup) -eq $false)
			{
				New-ADGroup -Name $FullAccessRoleGroup -Description "Role Group for Full Access to Mailbox $Name" -DisplayName $FullAccessRoleGroup -GroupCategory Security -GroupScope Global -Server $DC -Path (Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type "SharedMailboxRoleGroup")
			}
			if ((Test-CGAccountName -User $SendAsRAGroup) -eq $false)
			{
				New-ADGroup -Name $SendAsRAGroup -Description "Resource Access Group for SendAs for Mailbox $Name" -DisplayName $SendAsRAGroup -GroupCategory Security -GroupScope DomainLocal -Server $DC -Path (Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type "SharedMailboxRAGroup")
			}
			if ((Test-CGAccountName -User $SendAsRoleGroup) -eq $false)
			{
				New-ADGroup -Name $SendAsRoleGroup -Description "Role Group for SendAs to Mailbox $Name" -DisplayName $SendAsRoleGroup -GroupCategory Security -GroupScope Global -Server $DC -Path (Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type "SharedMailboxRoleGroup")
			}
			
			$FAGroupDN = (Get-ADGroup $FullAccessRAGroup -Server $DC).DistinguishedName
			$SAGroupDN = (Get-ADGroup $SendAsRAGroup -Server $DC).DistinguishedName
			$FARoleGroupDN = (Get-ADGroup $FullAccessRoleGroup -Server $DC).DistinguishedName
			$SARoleGroupDN = (Get-ADGroup $SendAsRoleGroup -Server $DC).DistinguishedName
			
			if ((Get-ADGroupMember $FAGroupDN -Server $DC) -eq $null)
			{
				Add-ADGroupMember $FullAccessRAGroup $FullAccessRoleGroup -Server $DC
			}
			elseif ((Get-ADGroupMember $FAGroupDN -Server $DC).DistinguishedName -notcontains (Get-ADGroup $FARoleGroupDN -Server $DC).DistinguishedName)
			{
				Add-ADGroupMember $FullAccessRAGroup $FullAccessRoleGroup -Server $DC
			}
			
			if ((Get-ADGroupMember $SAGroupDN -Server $DC) -eq $null)
			{
				Add-ADGroupMember $SendAsRAGroup $SendAsRoleGroup -Server $DC
			}
			elseif ((Get-ADGroupMember $SAGroupDN -Server $DC).DistinguishedName -notcontains (Get-ADGroup $SARoleGroupDN -Server $DC).DistinguishedName)
			{
				Add-ADGroupMember $SendAsRAGroup $SendAsRoleGroup -Server $DC
			}
			
			$oldUserNotes = (Get-ADUser $Name -Server $DC -Properties *).info
			$newUserNotes = $oldUserNotes + "`r`nFor SendAs Permissions add to Group: ${SendAsRoleGroup}`r`nFor Full Access Permissions add to Group: ${FullAccessRoleGroup}"
			Set-ADUser $Name -Replace @{ info = $newUserNotes } -Server $DC
			
			$FAGroupDN = (Get-ADGroup $FullAccessRAGroup -Server $DC).DistinguishedName
			$SAGroupDN = (Get-ADGroup $SendAsRAGroup -Server $DC).DistinguishedName
			
			Write-Verbose -Message "Setting Mailbox Full Access Permissions for $Name on $DC"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$DC,
					$GroupDN) Add-MailboxPermission -Identity $Username -User $GroupDN -AccessRights FullAccess -DomainController $DC
			} -ArgumentList ($Name, $DC, $FAGroupDN) | Out-Null
			Write-Verbose -Message "Setting Mailbox SendAs Permissions for $Name on $DC"
			Invoke-Command -Session $ExchSession {
				param ($UserName,
					$DC,
					$GroupDN) Add-ADPermission -Identity $Username -User $GroupDN -ExtendedRights "Send As" -DomainController $DC
			} -ArgumentList ($Name, $DC, $SAGroupDN) | Out-Null
		}
		else
		{
			Write-Error "Account already exists"
		}
	}
	end
	{
		try
		{
			Remove-PSSession -Session $ExchSession
		}
		catch
		{
			Write-Error "Exchange Remote Session might still be open"
		}
	}
}
Export-ModuleMember -Function New-CGSharedMailbox


<#
	.SYNOPSIS
		A brief description of the New-CGEmployee function.
	
	.DESCRIPTION
		A detailed description of the New-CGEmployee function.
	
	.PARAMETER ActiveSyncEnabled
		A description of the ActiveSyncEnabled parameter.
	
	.PARAMETER Contractor
		A description of the Contractor parameter.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.PARAMETER FirstName
		A description of the FirstName parameter.
	
	.PARAMETER LastName
		A description of the LastName parameter.
	
	.PARAMETER LyncEnabled
		A description of the LyncEnabled parameter.
	
	.PARAMETER Middle
		A description of the Middle parameter.
	
	.PARAMETER Office
		A description of the Office parameter.
	
	.PARAMETER Organization
		A description of the Organization parameter.
	
	.PARAMETER Template
		A description of the Template parameter.
	
	.EXAMPLE
		PS C:\> New-CGEmployee -ActiveSyncEnabled $value1 -Contractor
	
	.NOTES
		Additional information about the function.
#>
function New-CGEmployee
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[ValidateLength(1, 20)]
		[string]$FirstName,
		[parameter(Mandatory = $true)]
		[ValidateLength(1, 20)]
		[string]$LastName,
		[parameter(Mandatory = $false)]
		[ValidateLength(0, 1)]
		[string]$Middle,
		[parameter(Mandatory = $true)]
		[string]$Office,
		[parameter(Mandatory = $true)]
		[string]$Template,
		[parameter(Mandatory = $true)]
		[string]$Domain,
		[parameter(Mandatory = $true)]
		[string]$Organization,
		[parameter(Mandatory = $true)]
		[string]$Department,
		[parameter(Mandatory = $true)]
		[boolean]$ActiveSyncEnabled,
		[parameter(Mandatory = $true)]
		[boolean]$LyncEnabled,
		[parameter(Mandatory = $false)]
		[switch]$Contractor,
		[parameter(Mandatory = $false)]
		[boolean]$MailEnabled = $true,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[switch]$OverrideDC,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[string]$Server
		
	)
	
	begin
	{
		$Date = Get-Date -Format MM-dd-yyyy
		$CreatedBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
		if ($Contractor.IsPresent)
		{
			$Type = "Contractor"
		}
		else
		{
			$Type = "Employee"
		}
		$CannotChangePassword = $false
		$PasswordNeverExpires = $false
		$ChangePasswordAtLogon = $false
		
		Test-Domain -Domain $Domain
		Test-Department -Department $Department
		Test-Organization -Domain $Domain -Organization $Organization
		
		
	}
	process
	{
		$OUPath = Get-CGOUPath -Domain $Domain -Organization $Organization -Department $Department -Type $Type
		if ($OUPath -eq $null)
		{
			Write-Error "Invalid OU"
		}
		$UPNsuffix = "@$((Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']").node.DNSSuffix)"
		$OrgName = (Select-Xml -XML $config -XPath "//domain[shortname='$Domain']/organization[name='$Organization']").node.fullName
		$LogonScript = "$((Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']").node.logonscript)"
		$Attributes = Get-CGAcctAttributes -Type $Type
		if ($Contractor.IsPresent)
		{
			$Password = "Capitals10"
		}
		else
		{
			$Password = "Capitals08"
		}
		$AccountPassword = (ConvertTo-SecureString $Password -AsPlainText -Force)
		
		if ($OverrideDC)
		{
			$DC = $Server
		}
		else
		{
			$DC = Get-ADDomainController -Discover -Service ADWS -DomainName $Domain | Select -ExpandProperty HostName
		}
		
		$TemplateName = Get-CGTemplate -TemplateName -Department $Department -RoleName $Template
		
		try
		{
			if ($TemplateName -ne "NoTemplate")
			{
				Get-ADUser $TemplateName -Server $DC
			}
		}
		catch
		{
			Write-Error "Template: $TemplateName does not exist in the $Domain domain"
		}
		
		if (($Middle) -and ($Middle.Length -gt 0))
		{
			$Name = Get-CGAccountName -FirstName $FirstName -Middle $Middle -LastName $LastName -OverrideDC:$OverrideDC -Server $DC
		}
		else
		{
			$Name = Get-CGAccountName -FirstName $FirstName -LastName $LastName -OverrideDC:$OverrideDC -Server $DC
		}
		
		if ($Contractor.IsPresent)
		{
			$DisplayName = "$FirstName $LastName (Contractor)"
		}
		else
		{
			$DisplayName = "$FirstName $LastName"
		}
		
		Write-Verbose "Using $name as username for $DisplayName"
		
		if ((Test-CGAccountName -User $Name -OverrideDC:$OverrideDC -Server $DC) -eq $false)
		{
			Write-Verbose "Creating $Type Account: $Name at $OUPath"
			New-ADUser -GivenName $FirstName -Surname $LastName -Initials $Middle -Office $Office -Name $Name -DisplayName $DisplayName -AccountPassword $AccountPassword -CannotChangePassword $CannotChangePassword -ChangePasswordAtLogon $ChangePasswordAtLogon -Company $OrgName -Department $Department -OtherAttributes $Attributes -PasswordNeverExpires $PasswordNeverExpires -Path $OUPath -UserPrincipalName "${Name}${UPNsuffix}" -ScriptPath $LogonScript -Enabled $true -Server $DC
			Write-Output "Account $Domain\$Name was succesfully created`n"
			
			if ($MailEnabled -eq $true)
			{
				New-CGMailbox -Name $Name -Domain $Domain -DomainController $DC -ActiveSyncEnabled $ActiveSyncEnabled
				Write-Output "Account $Domain\$Name was mailbox enabled`n"
			}
			
			
			if ($TemplateName -ne "NoTemplate")
			{
				$Groups = (Get-CGTemplate -Groups -Department $Department -RoleName $Template -DC $DC).MemberOf
				Copy-CGGroupMembership -Source $TemplateName -Target $Name -DC $DC
				Write-Output "Added User to Groups: `n"
				Write-Output "$$$Groups"
			}
			else
			{
				Write-Output "No Template was used for Group Memeberships`n"
			}
			
			if ($Contractor.IsPresent)
			{
				Set-CGAccountExpiration -UserName $Name -DomainController $DC
			}
			
			if ($LyncEnabled)
			{
				Set-CGLyncUser -UserName $Name -DomainController $DC
				Write-Output "Account $Domain\$Name was succesfully Lync enabled`n"
			}
		}
		else
		{
			Write-Error "Account already exists"
		}
	}
	end
	{
		
	}
}
Export-ModuleMember -Function New-CGEmployee


<#
	.SYNOPSIS
		A brief description of the Set-CGLyncUser function.
	
	.DESCRIPTION
		A detailed description of the Set-CGLyncUser function.
#>
function Set-CGLyncUser
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$UserName,
		[parameter(Mandatory = $true)]
		[string]$DomainController
	)
	
	begin
	{
		$RegistrarPool = 'cg01skypprd100.us.costar.local'
		$LyncUri = 'https://cg01skypprd100.us.costar.local/ocspowershell'
		try
		{
			$LyncSession = New-PSSession -ConnectionUri $LyncUri -Authentication 'NegotiateWithImplicitCredential'
		}
		catch
		{
			Write-Error "Cannot connect to $RegistrarPool"
		}
	}
	process
	{
		try
		{
			Invoke-Command -Session $LyncSession {
				param ($UserName,
					$DC,
					$RegistrarPool) Enable-CsUser $UserName -RegistrarPool $RegistrarPool -SipAddressType 'EmailAddress' -DomainController $DC
			} -ArgumentList ($UserName, $DomainController, $RegistrarPool)
			#May need to add this back in at a later time but the property does not exist in Set-CSUser: -IPPBXSoftPhoneRoutingEnabled $False. By default this is $false anyway
			Invoke-Command -Session $LyncSession {
				param ($UserName,
					$DC) Set-CsUser $UserName -AudioVideoDisabled $True -RemoteCallControlTelephonyEnabled $False -EnterpriseVoiceEnabled $False -DomainController $DC
			} -ArgumentList ($UserName, $DomainController)
		}
		catch
		{
			Write-Error "Could not set the Lync User or the properties using $DC"
			Write-Error $_.Exception.Message
		}
	}
	end
	{
		Remove-PSSession $LyncSession
	}
}
Export-ModuleMember -Function Set-CGLyncUser

<#
	.SYNOPSIS
		A brief description of the Test-Domain function.
	
	.DESCRIPTION
		A detailed description of the Test-Domain function.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.EXAMPLE
		PS C:\> Test-Domain -Domain 'Value1' -PipelineVariable $value2
	
	.NOTES
		Additional information about the function.
#>
function Test-Domain
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$Domain
	)
	
	if (!(Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']"))
	{
		$ValidDomains = (Select-Xml -XML $config -XPath "//domain").node.shortname -join ','
		Write-Error "Domain: $Domain is invalid. Valid Domains are: $ValidDomains"
	}
	
}


<#
	.SYNOPSIS
		A brief description of the Test-Department function.
	
	.DESCRIPTION
		A detailed description of the Test-Department function.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.EXAMPLE
		PS C:\> Test-Department -Department 'Value1' -PipelineVariable $value2
	
	.NOTES
		Additional information about the function.
#>
function Test-Department
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$Department
	)
	
	if (!(Select-Xml -XML $config -XPath "//departments/department[@name = '$Department']"))
	{
		$ValidDepts = (Select-Xml -XML $config -XPath "//departments/department/@name") -join ','
		Write-Error "Departments: $Department is invalid. Valid Departments are: $ValidDepts"
	}
	
}


<#
	.SYNOPSIS
		A brief description of the Test-Organization function.
	
	.DESCRIPTION
		A detailed description of the Test-Organization function.
	
	.PARAMETER Domain
		A description of the Domain parameter.
	
	.PARAMETER Organization
		A description of the Organization parameter.
	
	.EXAMPLE
		PS C:\> Test-Organization -Domain 'Value1' -Organization 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Test-Organization
{
	[Cmdletbinding()]
	param (
		[parameter(Mandatory = $true)]
		[string]$Domain,
		[parameter(Mandatory = $true)]
		[string]$Organization
	)
	
	if (!(Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']/organization[name = '$Organization']"))
	{
		$ValidOrgs = (Select-Xml -XML $config -XPath "//domain[shortname = '$Domain']/organization").node.Name -join ','
		Write-Error "Organization: $Organization is invalid. Valid Organizations are: $ValidOrgs"
	}
}

<#
	.SYNOPSIS
		A brief description of the Get-CGAccountName function.
	
	.DESCRIPTION
		A detailed description of the Get-CGAccountName function.
	
	.PARAMETER FirstName
		A description of the FirstName parameter.
	
	.PARAMETER LastName
		A description of the LastName parameter.
	
	.PARAMETER Middle
		A description of the Middle parameter.
	
	.EXAMPLE
		PS C:\> Get-CGAccountName -FirstName 'Value1' -LastName 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Get-CGAccountName
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$FirstName,
		[Parameter(Mandatory = $true)]
		[System.String]$LastName,
		[Parameter(Mandatory = $false)]
		[System.String]$Middle,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[switch]$OverrideDC,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[string]$Server
	)
	begin
	{
		
		$tmpUserName = $FirstName.Substring(0, 1) + $LastName
		$UserNameOK = $false
		$count = 1
		if (!$OverrideDC)
		{
			$Server = ""
		}
	}
	process
	{
		while (!$UserNameOK)
		{
			if ((Test-CGAccountName -User $tmpUserName -OverrideDC:$OverrideDC -Server $Server) -and ($Middle))
			{
				if ($count -eq 1)
				{
					$tmpUserName = $FirstName.Substring(0, 1) + $Middle.Substring(0, 1) + $LastName
				}
				else
				{
					$tmpUserName = $FirstName.Substring(0, 1) + $Middle.Substring(0, 1) + $LastName + $($count - 1)
				}
			}
			elseif ((Test-CGAccountName -User $tmpUserName -OverrideDC:$OverrideDC -Server $Server) -and (!$Middle))
			{
				$tmpUserName = $FirstName.Substring(0, 1) + $LastName + $count
			}
			else
			{
				$UserNameOK = $true
			}
			
			$count++
			
		}
		Write-Output $tmpUserName.ToLower()
	}
	end
	{
		
	}
}
Export-ModuleMember -Function Get-CGAccountName


<#
	.SYNOPSIS
		A brief description of the Get-CGTemplate function.
	
	.DESCRIPTION
		A detailed description of the Get-CGTemplate function.
	
	.PARAMETER DC
		A description of the DC parameter.
	
	.PARAMETER Department
		A description of the Department parameter.
	
	.PARAMETER Groups
		A description of the Groups parameter.
	
	.PARAMETER PipelineVariable
		A description of the PipelineVariable parameter.
	
	.PARAMETER RoleName
		A description of the RoleName parameter.
	
	.PARAMETER TemplateName
		A description of the TemplateName parameter.
	
	.EXAMPLE
		PS C:\> Get-CGTemplate -DC 'Value1' -Department 'Value2'
	
	.NOTES
		Additional information about the function.
#>
function Get-CGTemplate
{
	[Cmdletbinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$Department,
		[Parameter(Mandatory = $true)]
		[System.String]$RoleName,
		[Parameter(Mandatory = $true, ParameterSetName = 'GetGroups')]
		[System.String]$DC,
		[Parameter(Mandatory = $true, ParameterSetName = 'GetTemplate')]
		[switch]$TemplateName,
		[Parameter(Mandatory = $true, ParameterSetName = 'GetGroups')]
		[switch]$Groups
	)
	
	if ($TemplateName.IsPresent)
	{
		if ($RoleName -eq "NoTemplate")
		{
			Write-Output $RoleName
		}
		else
		{
			Write-Output (Select-Xml -XML $Config -XPath "//department[@name = '$($Department)']/template[text() = '$($RoleName)']").node.name
		}
	}
	elseif ($Groups.IsPresent)
	{
		$TemplateUser = Get-CGTemplate -TemplateName -Department $Department -RoleName $RoleName
		if (($RoleName -ne "NoTemplate") -and ($TemplateUser -ne "NoTemplate"))
		{
			
			Get-ADUser $TemplateUser -Server $DC -Properties MemberOf | Select-Object MemberOf
			
		}
		else
		{
			Write-Verbose "No need to get groups"
		}
	}
}
Export-ModuleMember -Function Get-CGTemplate


<#
	.SYNOPSIS
		A brief description of the Copy-CGGroupMembership function.
	
	.DESCRIPTION
		A detailed description of the Copy-CGGroupMembership function.
	
	.PARAMETER DC
		A description of the DC parameter.
	
	.PARAMETER Source
		A description of the Source parameter.
	
	.PARAMETER Target
		A description of the Target parameter.
	
	.EXAMPLE
		PS C:\> Copy-CGGroupMembership -DC 'Value1' -PipelineVariable $value2
	
	.NOTES
		Additional information about the function.
#>
function Copy-CGGroupMembership
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[System.String]$Source,
		[Parameter(Mandatory = $true)]
		[System.String]$Target,
		[Parameter(Mandatory = $true)]
		[System.String]$DC
	)
	
	try
	{
		(Get-ADUser $Source -Server $DC -Properties MemberOf).memberOf | Add-ADGroupMember -Members $Target -Server $DC
	}
	catch
	{
		Write-Error "Failed to copy some or all groups"
		Write-Error ($_.Exception.Message)
	}
}
Export-ModuleMember -Function Copy-CGGroupMembership

<#
	.SYNOPSIS
		Sets the account expiration date
	
	.DESCRIPTION
		Sets the account expiration date to the value specified or to the next Friday 7 days from the current date (commonly used for contractor accounts). 
	
	.PARAMETER UserName
		A description of the UserName parameter.
	
	.PARAMETER ExpirationDate
		A description of the ExpirationDate parameter.
	
	.NOTES
		Additional information about the function.
#>
function Set-CGAccountExpiration
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $true)]
		[System.String]$UserName,
		[Parameter(Mandatory = $false)]
		[System.String]$DomainController,
		[Parameter(Mandatory = $false)]
		[System.DateTime]$ExpirationDate
	)
	
	if ($ExpirationDate)
	{
		$NewExpirationDate = $ExpirationDate.AddDays(1)
	}
	else
	{
		$NewExpirationDate = (@(@(0..7) | % { $(Get-Date "00:00").AddDays($_) } | ? { ($_ -gt $(Get-Date)) -and ($_.DayOfWeek -ieq "Monday") })[0]).AddDays(7)
	}
	
	Write-Verbose "Setting account expiration date for user $UserName to $NewExpirationDate UTC"
	try
	{
		if ($DomainController)
		{
			Set-ADAccountExpiration -identity $UserName -DateTime $NewExpirationDate -Server $DomainController
		}
		else
		{
			Set-ADAccountExpiration -identity $UserName -DateTime $NewExpirationDate
		}
	}
	catch
	{
		Write-Error "Could not set the expiration for account $UserName"
	}
	
	Write-Output "Expiration date for user $UserName successfully set to $NewExpirationDate UTC"
	
}
Export-ModuleMember -Function Set-CGAccountExpiration


<#
	.SYNOPSIS
		Gets the account expiration date
	
	.DESCRIPTION
		Sets the account expiration date to the value specified or to the next Friday 7 days from the current date (commonly used for contractor accounts). 
	
	.PARAMETER UserName
		A description of the UserName parameter.
	
	.PARAMETER ExpirationDate
		A description of the ExpirationDate parameter.
	
	.NOTES
		Additional information about the function.
#>
function Get-CGAccountExpiration
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory = $false)]
		[System.String]$UserName,
		[Parameter(Mandatory = $false)]
		[System.String]$DomainController,
		[Parameter(Mandatory = $true)]
		[ValidateSet("Current","New")]
		[System.String]$TimeFrame
		
	)
	
	[DateTime]$EpochDate = '1/1/1601'
	
	if ($TimeFrame -eq "Current" -and $UserName)
	{
		if (!$DomainController)
		{
			$ExpirationDate = ((Get-ADUser -Identity $UserName -Properties AccountExpires).AccountExpires)
		}
		else
		{
			$ExpirationDate = ((Get-ADUser -Identity $UserName -Server $DomainController -Properties AccountExpires).AccountExpires)
		}
		
		if ($ExpirationDate -eq '9223372036854775807' -or $ExpirationDate -eq '0')
		{
			Write-Error "There is no expiration set for this user"
		}
		else
		{
			$ExpirationDate = $EpochDate.AddTicks($ExpirationDate)
		}
	}
	elseif ($TimeFrame -eq "New")
	{
		$ExpirationDate = (@(@(0..7) | % { $(Get-Date "00:00").AddDays($_) } | ? { ($_ -gt $(Get-Date)) -and ($_.DayOfWeek -ieq "Monday") })[0]).AddDays(7)
	}
	else
	{
		Write-Error "Please provide a User DN or UserName to the -UserName parameter"
	}
	
	
	$ExpirationDate
}
Export-ModuleMember -Function Get-CGAccountExpiration



<#
	.SYNOPSIS
		A brief description of the New-CGExchangeSession function.

	.DESCRIPTION
		A detailed description of the New-CGExchangeSession function.

	.PARAMETER  Domain
		The description of a the Domain parameter.

	.EXAMPLE
		PS C:\> New-CGExchangeSession -Domain 'Domain.FQDN'
		
	.INPUTS
		System.String

	.OUTPUTS
		PSSession Object

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
function New-CGExchangeSession
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[System.String]$Domain
	)
	begin
	{
		switch ($Domain)
		{
			"US" {
				$Uri = "http://dccasprd101.us.costar.local/PowerShell/"
			}
			"UK" {
				$Uri = "http://ukexchprd100.uk.costar.local/PowerShell/"
			}
			default
			{
				$Uri = "http://dccasprd101.us.costar.local/PowerShell/"
			}
			
		}
		
		try
		{
			$ExchSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $uri -Authentication Kerberos
			Write-Verbose "Connected to $Uri"
		}
		catch
		{
			Write-Error "Could not get connection to $uri"
		}
	}
	process
	{
		try
		{
			return $ExchSession
		}
		catch
		{
		}
	}
	end
	{
		
	}
}
Export-ModuleMember -Function New-CGExchangeSession


<#
	.SYNOPSIS
		A brief description of the Find-CGUser function.

	.DESCRIPTION	
		A detailed description of the Find-CGUser function.

	.PARAMETER  UserName
		The description of a the UserName parameter.

	.PARAMETER  FirstName
		The description of a the FirstName parameter.
	
	.PARAMETER  LastName
		The description of a the LastName parameter.

	.EXAMPLE
		PS C:\> Find-CGUser -UserName 'One value' -ParameterB 32
		'This is the output'
		This example shows how to call the Find-CGUser function with named parameters.

	.EXAMPLE
		PS C:\> Find-CGUser 'One value' 32
		'This is the output'
		This example shows how to call the Find-CGUser function with positional parameters.

	.INPUTS
		System.String,System.Int32

	.OUTPUTS
		System.String

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
function Find-CGUser
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $false)]
		[String]$UserName,
		[Parameter(Mandatory = $false)]
		[String]$FirstName,
		[Parameter(Mandatory = $false)]
		[String]$LastName,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[Switch]$OverrideDC,
		[parameter(Mandatory = $false, ParameterSetName = 'Override')]
		[String]$Server
	)
	
	
	begin
	{
		$ForestList = @("costar.local")
		$FilterString = "enabled -eq 'true' -and objectcategory -eq 'user' "
		$UserResults = New-Object System.Collections.ArrayList
		
		if ($UserName -and $UserName -ne "")
		{
			$FilterString += "-and samaccountname -eq '$UserName' "
		}
		if ($FirstName -and $FirstName -ne "")
		{
			$FilterString += "-and givenName -eq '$FirstName' "
		}
		if ($LastName -and $LastName -ne "")
		{
			$FilterString += "-and sn -eq '$LastName' "
		}
		
	}
	process
	{
		if (!$OverrideDC)
		{
			foreach ($Forest in $ForestList)
			{
				$GC = (Get-ADForest $Forest).DomainNamingMaster
				$SearchBase = (Get-ADDomain (Get-ADForest $Forest).RootDomain).DistinguishedName
				Write-Verbose "Querying Server: ${GC}:3268 with SearchBase:${SearchBase} using Filter of $FilterString"
				$UserResults += Get-ADUser -Filter $FilterString -SearchBase $SearchBase -SearchScope SubTree -Server ${GC}':3268' -Properties mail
			}
		}
		else
		{
			$GC = $Server
			$DomainString = $Server.SubString((($Server.split(".")[0]).Length) + 1)
			$SearchBase = (Get-ADDomain $DomainString).DistinguishedName
			Write-Verbose "Querying Server: ${GC}:3268 with SearchBase:${SearchBase} using Filter of $FilterString"
			$UserResults += Get-ADUser -Filter $FilterString -SearchBase $SearchBase -SearchScope SubTree -Server ${GC}':3268' -Properties mail
		}
	}
	end
	{
		$UserResults
	}
}
Export-ModuleMember -Function Find-CGUser


<#
	.SYNOPSIS
		A brief description of the Disable-CGAccount function.

	.DESCRIPTION
		A detailed description of the Disable-CGAccount function.

	.PARAMETER  Identity
		The description of a the AccountDN parameter.

	.EXAMPLE
		PS C:\> Disable-CGAccount -Identity CN=Users,OU=Users,DC=domain,DC=com 
		'This is the output'
		This example shows how to call the Disable-CGAccount function with positional parameters.

	.INPUTS
		System.String

	.OUTPUTS
		System.String

	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>

function Disable-CGAccount
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[System.String]$Identity,
		[Parameter(Mandatory = $false)]
		[System.String]$DC = 'dcus2.us.costar.local'
	)
	
	
	$DisabledBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	$Date = Get-Date -Format MM-dd-yyyy
	$PrimaryGroupDN = (Get-ADUser $Identity -Properties PrimaryGroup -Server $DC).PrimaryGroup
	$GroupsforUser = Get-ADPrincipalGroupMembership -Identity $Identity -Server $DC | where { $_.DistinguishedName -ne $PrimaryGroupDN }
	
	$oldUserNotes = (Get-ADUser $Identity -Server $DC -Properties *).info
	
	$newUserNotes = $oldUserNotes + "`r`n`r`nDisabled on $Date by $DisabledBy"
	$newUserNotes = $newUserNotes + "`r`n`r`nRemoved from Groups:"
	
	Write-Output "Removed User $Identity from Groups:"
	
	foreach ($Group in $GroupsforUser)
	{
		$GroupDN = $Group.DistinguishedName
		try
		{
			$Group | Remove-ADGroupMember -Members $Identity -Server $DC -Confirm:$false
			$newUserNotes = $newUserNotes + "`r`n$GroupDN"
			Write-Output $GroupDN
		}
		catch
		{
			Write-Output "Could not remove from group: $GroupDN"
		}
		
	}
		
	Set-ADUser $Identity -Replace @{ info = $newUserNotes } -Server $DC
	
	try
	{
		Disable-ADAccount -Identity $Identity -Server $DC
	}
	catch
	{
		Write-Output "We were not able to disable the user account for $Identity"
	}
	
	
}
Export-ModuleMember -Function Disable-CGAccount