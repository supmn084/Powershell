## Playing with Pester Tests for SQL Services.ps1
Describe 'Testing if SQL services are running on multiple servers' {

    $serverName = 'Placeholder for now add in login later'
    $serviceName = 'MSSQLSERVER'

    if (-not (Test-Connection -ComputerName $serverName -Quiet -Count 1)) {
        Context 'Testing if Server is offline' {
            Set-ItResult -Inconclusive
        }
    }
    else { 
        $service = Get-Service -ComputerName $serverName -Name $serviceName -ErrorVariable err -ErrorAction SilentlyContinue
        if ($err -and $err.Exception.Message -like '*Cannot find any service with service name*') {
            Context 'Service is not running' {
                Set-ItResult -Inconclusive
            }
        }
        else {
            Context 'when the server is online, and the service is running' {

                $status = (Get-Service -ComputerName $serverName -Name $serviceName).Status

                It 'service is running' {
                    $status | Should -Be 'Running'
                }
            }
        }
    }
}