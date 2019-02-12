Get-WmiObject win32_bios|Format-Table -AutoSize

Get-Process |Format-Table -AutoSize -Property *
Get-Process |Format-Table -Property ID,Name,Respondint -AutoSize
Get-Process |Format-Table * -AutoSize

Get-Service | Sort-Object Status |Format-Table -GroupBy status

Get-Service |Format-Table Name,Status,DisplayName -AutoSize -wrap

Get-Service |Format-List
Get-Process |Format-Wide name -Column 4


Get-Service |Format-Table @{name ='ServiceName';Expression={$_.Name}},Status,DisplayName

Get-Process |Format-Table name, @{name='VM(MB)';expression={$_.VM / 1MB -as [int]}} -AutoSize


Get-Process|
Format-Table Name,
@{name='VM(MB)';expression={$_.VM /1mb -as [int]}} -AutoSize

Get-Service |Format-wide
Get-Service |Format-Wide |Out-Host

Get-Service |select Name,DisplayName,Status |Format-Table| ConvertTo-Html |Out-File services.html

Get-Process|Out-GridView|Format-Table

