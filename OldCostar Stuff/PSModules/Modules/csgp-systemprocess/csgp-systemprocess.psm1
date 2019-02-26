<#
	.SYNOPSIS
		This function prepares the System.Diagnostics.Process parameters needed to get a good 
		clean invocation of a shell command

	.DESRIPTION
		Does not attempt to parse the output
#>
function new-systemprocess {
	[CmdletBinding()]
	param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$cmd,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string]$cmdArgs, 
		[parameter(Mandatory=$FALSE)]
		[ValidateNotNullOrEmpty()]
		[switch]$echo
		)
	
	BEGIN	{

	}
	
	PROCESS { 
	
	$ps = new-object System.Diagnostics.Process 
	$ps.StartInfo.Filename = $cmd 
	$ps.StartInfo.Arguments = " $cmdArgs"
	if ($echo)	{
		Write-Verbose "$($ps.StartInfo.Filename) $($ps.StartInfo.Arguments)"
	}
	$ps.StartInfo.RedirectStandardOutput = $True 
	$ps.StartInfo.UseShellExecute = $false
	$ps.StartInfo.CreateNoWindow = $true
	$ps.start() | Out-Null
	# $ps.WaitForExit()	# Thsi can cause the command to run, but hang, not producing output until the exe is killed.
	[string] $result = $ps.StandardOutput.ReadToEnd();
	$result = $result.trim()
	write-output $result
	}
	
	END {
	
	}
}
