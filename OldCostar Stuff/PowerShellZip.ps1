function New-Zip
{
	param([string]$zipfilename)
	set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
	(dir $zipfilename).IsReadOnly = $false
	
	# usage: new-zip c:\demo\myzip.zip
}

function Add-Zip
{
	param([string]$zipfilename)

	if(-not (test-path($zipfilename)))
	{
		set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
		(dir $zipfilename).IsReadOnly = $false	
	}
	
	$shellApplication = new-object -com shell.application
	$zipPackage = $shellApplication.NameSpace($zipfilename)
	
	foreach($file in $input) 
	{ 
            $zipPackage.CopyHere($file.FullName)
            Start-sleep -milliseconds 500
	}
	
# Add files to a zip via a pipeline
# usage: dir c:\demo\files\*.* -Recurse | add-Zip c:\demo\myzip.zip

}

function Get-Zip
{
	param([string]$zipfilename)
	if(test-path($zipfilename))
	{
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$zipPackage.Items() | Select Path
	}
# List the files in a zip
# usage: Get-Zip c:\demo\myzip.zip
}

function Extract-Zip
{
	param([string]$zipfilename, [string] $destination)

	if(test-path($zipfilename))
	{	
		$shellApplication = new-object -com shell.application
		$zipPackage = $shellApplication.NameSpace($zipfilename)
		$destinationFolder = $shellApplication.NameSpace($destination)
		$destinationFolder.CopyHere($zipPackage.Items())
	}
# Extract the files form the zip
# usage: extract-zip c:\demo\myzip.zip c:\demo\destination
}

#new-zip c:\temp\test1.zip
#dir C:\temp\cdrom | add-zip c:\temp\test1.zip

new-zip C:\temp\esxplot.zip
dir C:\temp\esxplot\ -recurse | add-zip C:\temp\esxplot.zip

