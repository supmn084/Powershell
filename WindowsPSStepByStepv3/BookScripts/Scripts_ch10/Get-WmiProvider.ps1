Function Get-WmiProvider
{
 Param(
  [string]$nameSpace,
  [string]$computer)
  Get-CimInstance -ClassName __Provider -namespace $namespace | 
  Sort-Object -property Name | 
  Select-Object name
} #end function Get-WmiProvider

Get-WmiProvider -nameSpace root\cimv2 -computer $env:COMPUTERNAME
