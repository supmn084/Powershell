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

function Get-IniValues {
[CmdletBinding(supportsshouldprocess=$true)]
	param (
	[Parameter(Mandatory=$True,ValueFromPipeline=$false)]
	[string][String]$iniFile
	)

	BEGIN	{

	}

	PROCESS	{
		$ini = Get-Content $iniFile
		$inipairs = @{}
		
		foreach ($entry in $ini)	{
			if ($entry -match '^[ \t]*$') { continue }	# skip blank lines
			if ($entry -match '^\s*#') 	{ continue } # comments
			
			# everything else in the .ini file should be a unique name=value pair
			# We'll pop them into a hash
			
			($entryName,$entryValue) = $entry -split ('=')
			$inipairs.add($entryName,$entryValue)
		}
		return $inipairs
	}
	END	{

	}	

}

