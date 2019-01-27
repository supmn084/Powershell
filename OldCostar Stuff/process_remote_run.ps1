

# Change \\mycomputer\d$\ipconfig to the location where you want to store the output files.
$log_destination = "C:\temp\prodro"
$portQry = "c:\IT\PortQry.exe"

# Change D:\servers.txt to your input file's pathname.
# $servers = get-content d:\servers.txt
$servers = get-content h:\serverlist\product-app-web-all.txt

foreach ($s in $servers)
{
	# copy "$portQry" \\$s\c$\it
	$result = ([WmiClass]"\\$s\ROOT\CIMV2:Win32_Process").create("cmd /c c:\it\PortQry.exe -n dcsqlprd560 -p tcp -e 1433 -l c:\it\$s-dcsqlprd560.txt -y")
	switch ($result.returnvalue) 
	    { 
        	0 {"$s Successful Completion."} 
	        2 {"$s Access Denied."} 
        	3 {"$s Insufficient Privilege."} 
	        8 {"$s Unknown failure."} 
        	9 {"$s Path Not Found."} 
	        21 {"$s Invalid Parameter."} 
        	default {"$s Could not be determined."}
	    }	

	if ($result.returnvalue -eq 0)
	{

	[diagnostics.process]::start("powershell", "-command & {move-item -path \\$s\c$\it\$s-dcsqlprd560.txt $log_destination -force}").waitforexit(3000)

	}
}





  
