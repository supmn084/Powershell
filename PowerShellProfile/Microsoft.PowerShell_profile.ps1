## Change to Git Directory for Powershell
cd C:\dev\Powershell
# Change the prompt
function Global:Prompt{
    $Time = Get-Date -Format "hh:mm:ss"
    $Directory = (Get-Location).Path.Replace($HOME, "~")
    
    Write-Host "[$Time] " -ForegroundColor Yellow -NoNewline
    Write-Host "$Directory >" -NoNewline

    return " "
    }
## Imports and set's up some default troubleshooting utilities for  fun
Import-Module TroubleshootingPack
$networkpack=Get-TroubleshootingPack C:\windows\diagnostics\system\Networking
$speechpack=Get-TroubleshootingPack C:\windows\diagnostics\system\Speech
$bluescreenpack=Get-TroubleshootingPack C:\windows\diagnostics\system\BlueScreen

