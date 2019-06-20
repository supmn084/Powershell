#This script is setup to take a list of computers, from an AD OU, or a text file, and then run Test-NetConnection for each server and port you wish. 
$SearchPath = Get-ADComputer -Server YOURDOMAIN -Filter * -SearchBase "THE OU STRUCTURE YOU WANT"
#This will get a list of computers from an OU in your domain. If you want to run from a text file, change this to Get-Content -Path "C:\Temp\MyServers.txt"
$ports = 443, 1433
#Enter in as many ports as you want here with commas between. 
$servers = $SearchPath.Name 
#Selects only the servernames from the AD search above.
$results = @()
#Array to store our goodies

Write-Output "Running Port Tests on $ports"

foreach ($s in $servers) {
    foreach ($p in $ports) {
        $a = Test-NetConnection -ComputerName $s -Port $p -WarningAction SilentlyContinue

        $results += New-Object -TypeName psobject -Property ([ordered]@{
                'Server'      = $a.ComputerName;
                'IP'          = $a.RemoteAddress;
                'Tested Port' = $a.RemotePort;
                'Test Status' = $a.tcpTestSucceeded
                #This makes a fun list of the output from each Test Net connection for each server, and selects the attirubtes selected. So you'll get an output below. 
            })
    }
}
Write-Output "Done!"
Write-Output $results | Out-GridView
#Remote the Out-GridView if you want it to show in your PS window. This makes it a little more usable. 