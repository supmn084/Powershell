# Function meant to poll on a remote server to get a service that is in a stopping, or stoppending state, grab the process PID. Present it to the user to confirm the force or not. Then Task kill force that process. 
Function Stop-PendingServices {
    [CmdletBinding()]
    Param
    (
        #Servername you want to run this on, or server(s)
        [Parameter(Position = 1)]
        [String]$ServerName,
        
        #ServiceName, if you have a service name in mind you want to stop. 
        [Parameter(Position = 2)]
        [String]$ServiceName
    )
    
    Invoke-Command -ComputerName $ServerName -ScriptBlock { 
        $ServiceNamePID = Get-Service | Where-Object { ($_.Status -eq 'StopPending' -or $_.Status -eq 'Stopping') }
        $ServicePID = (Get-WmiObject Win32_Service | Where-Object { $_.Name -eq $ServiceNamePID.Name }).ProcessID
        Stop-Process $ServicePID -Force
        
    }

}

#ToDO - Spit out services found in the state we want
# present those services to the user, Enter Y or N to kill them. 
# Spit out successful kill note. 