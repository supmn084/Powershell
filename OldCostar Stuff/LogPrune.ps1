# logprune.ps1
# delete iis log files

# variables
$days = 14
$logpath1 = "C:\Windows\System32\logfiles"
$logpath2 = "E:\logfiles"

get-childitem $logpath1 -recurse | where {$_.lastwritetime -lt (get-date).adddays(-$days) -and -not $_.psiscontainer} |% {remove-item $_.fullname -force}
get-childitem $logpath2 -recurse | where {$_.lastwritetime -lt (get-date).adddays(-$days) -and -not $_.psiscontainer} |% {remove-item $_.fullname -force}
