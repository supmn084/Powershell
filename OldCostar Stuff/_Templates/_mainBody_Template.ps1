#REQUIRES -Version 2.0

<#  
.SYNOPSIS  
    Tell the user about this script

.DESCRIPTION  
    A more detailed description
.NOTES  
	Put version specific notes here.  Or bugs, or ToDo
    
.EXAMPLE  
    Example 1     
.EXAMPLE    
    Example 2
#>
param ( 
	[Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]  
	[int]$foo=42 
)  

#
# Define global variables here
#
Set-StrictMode -version 2
$ErrorActionPreference = "Stop"


function CHANGEME {
	<#
		.SYNOPSIS
			This function does...

		.DESRIPTION
			A longer description
	#>
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$CHANGEME
		)

}


# 
# Main Body
#