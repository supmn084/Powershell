#Input and Outputs
$computername = Read-host "Enter a Computer Name"
#GUI Effort
$computer = [Microsoft.Visualbasic.Interaction]::InputBox('Enter a computername','Computer Name','localhost')
#Write Host
Write-host "Colorful" -Fore Yellow -back Magenta
#Write Output
Write-Output "Hello"|Where-Object {$_.length -gt 10}
#Write Host
Write-Host "hellodfdfdfdfd"|Where-Object {$_.length -gt 10}
#Warning
Write-Warning -Message "AHHHHHH" -WarningAction Continue
#Verbose
Write-Verbose -Message "AHHHHHHHHHHHHHHH" -WarningAction SilentlyContinue -Verbose
#Debug
Write-Debug -Message "OMG" -Debug
#Error
Write-Error -Message "You Broke this" -Category AuthenticationError -RecommendedAction "Try to actually Read this"
#info
Write-Information -MessageData "Hello"

#Lab Things
#1 Use write output to display the result of 100 multipled by 10
Write-Output (100*10)
#2 Use write host to display the result of 100 multiplied by 10
Write-host (100*10)
$a = 100*10
Write-Host $a
#3 Prompt the user to entar a name then display the name in yellow text
$name = Read-host "Enter a name" Write-host $name -ForegroundColor Yellow
#4 Prompt a user to enter a name and then display name longer than 5 characters
Read-Host "Enter a Name"|Where {$_.Length -gt 5}

















