function VERB-CHANGEME {
	<#
	.SYNOPSIS
	This script 
	.EXAMPLE
	---
	.EXAMPLE
	---
	.PARAMETER process
	---
	#>
	[cmdletBinding()]
	param(
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)]
		[String[]]$CHANGEME1,
		)

#
# Start the function
#
	BEGIN {
		# Begin is run once, at the beginning of the function, 
		#	before any pipeline objects are processed
		# You may insert module initialization procedures here but it's probably
		#	best to initialize in the main script and pass into this module
		
		
	}

	PROCESS {
		# Process is run for each object that is piped to that function.
		
		
		#
		# Perform an action and report if it fails (try/catch)
		#
		try {
			
			$result = "Hello World"
		
		} catch {
		
			$result = "Unable to find world" 
		}
		
		
		Write-Output $result	# Return back to caller, don't use 'return'
	}

	END {
		# Like Begin, End is run only once per function call
		# You may insert finalization procedures here
	}
} # 