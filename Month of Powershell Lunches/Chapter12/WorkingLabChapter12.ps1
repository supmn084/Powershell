##Chapter 12 Working Shell
install-module poshprivilege -Repository 'PSGallery' -Force
##
Get-Command -Module PoshPrivilege |Format-Table -AutoSize
###

Get-Privilege

##
Add-Privilege -AccountName Administrators -Privilege SeDenyBatchLogonRight

##Create folder
New-Item -Path C:\Labs  -ItemType Directory |Out-Null
#create my share
$myshare = "New-SmbShare -Name Labs -Path C:\Labs\ -Description "My lab share" -ChangeAccess Everyone -FullAccess Administrators -CachingMode Documents"

#Test
$myshare|Get-SmbShareAccess
