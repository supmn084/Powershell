#################
# function logger	v1.0
#################
# Usage: 
#	Step 1: in main body, define path to logfile: $logger_logfile = "c:\temp\blah.txt"
#	Step 2: use logger
#	logger  -loga -logf "both, log, stdout and array"
#	logger "none, should go to log and stdout "
#	logger -loga "array only & stdout"
 function logger	(  [string] $logInput , [switch] $loga, [switch] $logf) {
#	$logInput - Your data
#	$loga - will add data to global array $logger_array
#	$logf  - will log to log file 
#
# Note: if you are using PowerGUI be sure to set the 
#	Reset PowerShell runspace each time debugging is started
# option

# If array not defined, define global scope inside this function.
if (! $script:logger_array) 	{
	$script:logger_array = New-Object System.Collections.ArrayList
}

if ( ($logf) -and ($loga) )	{
	# Output to file and stdOut and array
	Add-content -path $logger_logfile -Value $logInput -PassThru
	[Void]$script:logger_array.Add($logInput)
} elseif ( ($logf) -and (! $loga) )	{
	# Output to file and stdOut
	Add-content -path $logger_logfile -Value $logInput -PassThru
} elseif ( ($loga) -and (! $logf) ) {
	# output only to array and stdOut
	[Void]$script:logger_array.Add($logInput)
	Write-Host $logInput
} else	{
	# no switches supplied, just write whatever we got to the log and stdOut
	Add-content -path $logger_logfile -Value $logInput -PassThru
}

}	# end Func


cls
$logger_logfile = "c:\temp\logger.log"


 logger  -loga -logf "both, log, stdout and array"
 logger "none, should go to log and stdout "
 logger -loga "array only & stdout"
#$logger_array