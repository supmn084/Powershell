#Stuff from the examples while working through chapter 14
Get-CimInstance -Namespace root\securitycenter2 -ClassName AntiSpywareProduct
#Fun WMI find with past things
Get-WmiObject win32_service | where {$_.state -eq 'running'}
#Get contents of core OS and Hardware stuff
Get-WmiObject -Namespace root\CIMv2 -List |where name -Like '*dis*'
Test-object

Testing Git Branches
testing merge Branches
yay 
yay
yay
yay
yay
acb
baaupdate.exec



Testing commiting again
Using Git Lense


git pull
git checkout -b testagain
git checkout master
git merge branchname
git push

testing pushes here
