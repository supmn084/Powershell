$x = 20

if($x -eq 10){
    Write-host ("Value of X is 10")
}elseif ($x -eq 20) {
    Write-Host ("Value of X is 20")
}elseif ($x -eq 45)
{Write-Host ("Value of X is 45")}

##2 Working Example Framework
#If (condition) {Block Command}
 
#elseIf (condition) {Block Command}
 
#...
 
#else {Block Command}
#

$Test = ping "google.com"

{$test}
if ($test.Address -eq "172.217.6.238") 
 {Write-Host "Looks to be working!"}
elseif ($test.address -notmatch "172.217.6.238") 
{Write-Host "Something Is Wrong With Your Internet!"}


