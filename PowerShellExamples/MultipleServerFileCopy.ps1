#This is meant to copy a file from a location, to a location on multiple servers. 
$Servername = Get-Content -Path "Location"
$FileToCopy = "Location"
foreach ($server in $servername) {
    $destinationfolder = "\\$server\c$\Temp"
    #Creates directory if it doesn't exist
    if (!(Test-Path -Path $destinationfolder)) {
        New-Item $destinationfolder -ItemType Directory
    }
    #copies items to directory for each server in the text file
    Copy-Item -Path $FileToCopy -Destination $destinationfolder
}
