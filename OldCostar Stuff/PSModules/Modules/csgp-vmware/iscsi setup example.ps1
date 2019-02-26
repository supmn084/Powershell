function Get-VMHostiSCSIBinding {
<#
 .SYNOPSIS
 Function to get the iSCSI Binding of a VMHost.

 .DESCRIPTION
 Function to get the iSCSI Binding of a VMHost.

 .PARAMETER VMHost
 VMHost to get iSCSI Binding for.

.PARAMETER HBA
 HBA to use for iSCSI

.INPUTS
 String.
 System.Management.Automation.PSObject.

.OUTPUTS
 VMware.VimAutomation.ViCore.Impl.V1.EsxCli.EsxCliObjectImpl.

.EXAMPLE
 PS> Get-VMHostiSCSIBinding -VMHost ESXi01 -HBA "vmhba32"

 .EXAMPLE
 PS> Get-VMHost ESXi01,ESXi02 | Get-VMHostiSCSIBinding -HBA "vmhba32"
#>
[CmdletBinding()][OutputType('VMware.VimAutomation.ViCore.Impl.V1.EsxCli.EsxCliObjectImpl')]

Param
 (

[parameter(Mandatory=$true,ValueFromPipeline=$true)]
 [ValidateNotNullOrEmpty()]
 [PSObject[]]$VMHost,
 [parameter(Mandatory=$true,ValueFromPipeline=$false)]
 [ValidateNotNullOrEmpty()]
 [String]$HBA
 )

begin {

 }

 process {

 foreach ($ESXiHost in $VMHost){

try {

if ($ESXiHost.GetType().Name -eq "string"){

 try {
 $ESXiHost = Get-VMHost $ESXiHost -ErrorAction Stop
 }
 catch [Exception]{
 Write-Warning "VMHost $ESXiHost does not exist"
 }
 }

 elseif ($ESXiHost -isnot [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]){
 Write-Warning "You did not pass a string or a VMHost object"
 Return
 }

 # --- Check for the iSCSI HBA
 try {

$iSCSIHBA = $ESXiHost | Get-VMHostHba -Device $HBA -Type iSCSI
 }
 catch [Exception]{

throw "Specified iSCSI HBA does not exist"
 }

# --- Set the iSCSI Binding via ESXCli
 Write-Verbose "Getting iSCSI Binding for $ESXiHost"
 $ESXCli = Get-EsxCli -VMHost $ESXiHost

$ESXCli.iscsi.networkportal.list($HBA)
 }
 catch [Exception]{

 throw "Unable to get iSCSI Binding config"
 }
 }
 }
 end {

 }
}


function Set-VMHostiSCSIBinding {
<#
 .SYNOPSIS
 Function to set the iSCSI Binding of a VMHost.

 .DESCRIPTION
 Function to set the iSCSI Binding of a VMHost.

 .PARAMETER VMHost
 VMHost to configure iSCSI Binding for.

.PARAMETER HBA
 HBA to use for iSCSI

.PARAMETER VMKernel
 VMKernel to bind to

.PARAMETER Rescan
 Perform an HBA and VMFS rescan following the changes

.INPUTS
 String.
 System.Management.Automation.PSObject.

.OUTPUTS
 None.

.EXAMPLE
 PS> Set-VMHostiSCSIBinding -HBA "vmhba32" -VMKernel "vmk1" -VMHost ESXi01 -Rescan

 .EXAMPLE
 PS> Get-VMHost ESXi01,ESXi02 | Set-VMHostiSCSIBinding -HBA "vmhba32" -VMKernel "vmk1"
#>
[CmdletBinding()]

Param
 (

[parameter(Mandatory=$true,ValueFromPipeline=$true)]
 [ValidateNotNullOrEmpty()]
 [PSObject[]]$VMHost,

[parameter(Mandatory=$true,ValueFromPipeline=$false)]
 [ValidateNotNullOrEmpty()]
 [String]$HBA,

[parameter(Mandatory=$true,ValueFromPipeline=$false)]
 [ValidateNotNullOrEmpty()]
 [String]$VMKernel,

[parameter(Mandatory=$false,ValueFromPipeline=$false)]
 [Switch]$Rescan
 )

begin {

}

 process {

 foreach ($ESXiHost in $VMHost){

try {

if ($ESXiHost.GetType().Name -eq "string"){

 try {
 $ESXiHost = Get-VMHost $ESXiHost -ErrorAction Stop
 }
 catch [Exception]{
 Write-Warning "VMHost $ESXiHost does not exist"
 }
 }

 elseif ($ESXiHost -isnot [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]){
 Write-Warning "You did not pass a string or a VMHost object"
 Return
 }

 # --- Check for the iSCSI HBA
 try {

$iSCSIHBA = $ESXiHost | Get-VMHostHba -Device $HBA -Type iSCSI
 }
 catch [Exception]{

throw "Specified iSCSI HBA does not exist"
 }

# --- Check for the VMKernel
 try {

$VMKernelPort = $ESXiHost | Get-VMHostNetworkAdapter -Name $VMKernel -VMKernel
 }
 catch [Exception]{

throw "Specified VMKernel does not exist"
 }

# --- Set the iSCSI Binding via ESXCli
 Write-Verbose "Setting iSCSI Binding for $ESXiHost"
 $ESXCli = Get-EsxCli -VMHost $ESXiHost

$ESXCli.iscsi.networkportal.add($iSCSIHBA.Device, $false, $VMKernel)

Write-Verbose "Successfully set iSCSI Binding for $ESXiHost"

# --- Rescan HBA and VMFS if requested
 if ($PSBoundParameters.ContainsKey('Rescan')){

Write-Verbose "Rescanning HBAs and VMFS for $ESXiHost"
 $ESXiHost | Get-VMHostStorage -RescanAllHba -RescanVmfs | Out-Null
 }
 }
 catch [Exception]{

 throw "Unable to set iSCSI Binding config"
 }
 }
 }
 end {

 }
}


