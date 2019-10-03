## Change to Git Directory for Powershell
cd C:\dev\
# Change the prompt
function Global:Prompt {
    $Time = Get-Date -Format "hh:mm:ss"
    $Directory = (Get-Location).Path.Replace($HOME, "~")
    
    Write-Host "[$Time] " -ForegroundColor Yellow -NoNewline
    Write-Host "$Directory >" -NoNewline

    return " "
}
#Alias for terraform binary on machine
New-Alias terraform "C:\Tools\terraform.exe"

