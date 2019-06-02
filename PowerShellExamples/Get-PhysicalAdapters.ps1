[cmdletbinding()]
Param(
    [Parameter(Mandatory = $True, HelpMessage = "Enter a computername here")]
    [Alias('Hostname')]
    [string]$computername
)
Write-Verbose "Getting Phyiscal Network Adapters from $computername"
Get-WmiObject -Class win32_networkadapter -ComputerName $computername |
Where-Object { $_physicalAdapter } |
Select-Object MACAddress, AdapterType, DeviceID, Name, Speed
Write-Verbose "Finished!"