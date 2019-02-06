####Get-Module *Trouble* -ListAvailable
####Import-Module TroubleshootingPack


$pack=Get-TroubleshootingPack C:\windows\diagnostics\system\Networking
Invoke-TroubleshootingPack $pack
#enter
#presents a set of options here to test
#Presents a set of websites to hit or not