# List of programs to start asynchronously

$Processes = @("cscript", "cscript", "cscript")
#$Processes = @("notepad.exe")
$args = "H:\dev\Performance\serverbench\sqlio\cpubusy.vbs"
# Maximum number of processes to run at once
$ProcessLimit = 2
 
$ProcessMonitor = @(); $i = 0
Do {
  # Get a list of running processes
  $Running = $ProcessMonitor | %{ Get-Process -Id $_.Id -ErrorAction SilentlyContinue }
 
  If ($Running.Count -lt $ProcessLimit) {
    # Start a process and store the details of the new process
    $ProcessMonitor += [Diagnostics.Process]::Start( $Processes[$i], $args )
    $i++
  } Else {
    # Too many queued... Sleep
    Start-Sleep -Seconds 1
  }
} Until ($i -eq ($Processes.Count))
 
# Wait until all processes are complete
While ($ProcessMonitor | %{ Get-Process -Id $_.Id -ErrorAction SilentlyContinue }) {
  # Processes still executing... Sleep
  Start-Sleep -Seconds 1
}
