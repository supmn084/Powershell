#chapter10 Lab

#1 Get all processes by running sort by responding
Get-Process |Format-Table name,id,Responding -GroupBy responding -AutoSize -Wrap
#2 Get all process with name and id include memory usage in MB
Get-Process|Format-Table Name,ID, @{l='VirtualMB';e={$_.vm/1mb}},@{l='PhysicalMB';e={$_.workingset/1MB}} -AutoSize
#3 Get event log filter by these
Get-EventLog -List |Format-Table @{l='LogName';e={$_.LogDisplayName}},@{l='RetDays';e={$_.MinimumRetentionDays}} -AutoSize
#4 Display services so seperate table for services started and stopped
Get-Service |Sort-Object Status -Descending|Format-Table -GroupBy ststus
#5 Display four column wide list of directories in root of C:
Dir C:\ -Directory |Format-Wide -Column 4
#6  create list of .exe files in C:\windows displaying name version information and file size. 
dir c:\windows\*.exe|Format-List Name,VersionInfo,@{Name='size'};expression={$_.length}}
