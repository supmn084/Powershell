##Playing with for each cmdlets
Get-Process | Write-Host $_.name -ForegroundColor Cyan
#This will fail because it doesn't understand the pipeline
Get-Process | ForEach-Object { Write-Host $_.Name -ForegroundColor Cyan -BackgroundColor Black }
#TaDa! now you can to a for each
#testing git on new machine


