
    $Services = Get-WmiObject -Class win32_service -Filter "state = 'stop pending'"
    if ($Services) {
        foreach ($service in $Services) {
            try {
                Stop-Process -Id $service.processid -Force -PassThru -ErrorAction Stop
            }
            catch {
                Write-Warning -Message "Unexpected Error. Error details: $_.Exception.Message"
            }
        }
    }
    else {
        Write-Output "There are currently no services with a status of 'Stopping'."
    }
}




Invoke-Command -ComputerName PowerShellVM -ScriptBlock ${Function:\Stop-PendingService} -Credential (Get-Credential)



Enter-PSSession -ComputerName POwershellVM -Credential (Get-Credential)

