<#
.SYNOPSIS
Manages ABC Operations
Version 1.00

.DESCRIPTION
A more verbose description of how to use this script

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function ABC {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[string]$thisVar="SomeDefaultValue",
	[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
	[int]$thatVar="1"
	)

	BEGIN	{

	}

	PROCESS	{
		write-verbose "$thisVar, $thatVar"
		
		# This allows you to use -WhatIf
		If ($PSCmdlet.ShouldProcess("Adding +1 to: $thatVar")) { 
			Write-Output $($thatVar + 1)
		}
	}
	END	{

	}	

}