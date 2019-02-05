#Get ADUser
Get-ADUser -Identity User01
#Get ADUsers which are enabled.
Get-ADUser -Filter 'Enabled -eq $True' | Select Name, Enabled |Format-Table -AutoSize
#Get ADUsers which are disabled.cm
Get-ADUser -Filter 'Enabled -eq $False'| Select Name, Enabled |Format-Table -AutoSize
#Get ADUser with Name matching "string"
Get-ADUser -Filter 'Name -like "*User*"'| Select Name, DistinguishedName |Format-Table -AutoSize
#Get AD Users from Certain OU
Get-ADUser -Filter * -SearchBase "OU=FFOUsers,DC=local,DC=dc"| Select Name, DistinguishedName |Format-Table -AutoSize
#Get AD Users from certain Departments
Get-ADUser -Filter 'department -eq "IT"' -Properties Department| Select Name, Department |Format-Table -AutoSize
#Get Enabled users from an OU
Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=FFOUsers,DC=local,DC=dc"| Select Name, Enabled |Format-Table -AutoSize
#Get Disabled users from an OU
Get-ADUser -Filter 'Enabled -eq $False' -SearchBase "OU=FFOUsers,DC=local,DC=dc"| Select Name, Enabled |Format-Table -AutoSize
#Get AD User Lock Out Status
Get-ADUser -Identity "User02" -Properties * | Select-Object Name,LockedOut|Format-Table -AutoSize
#Unlock AD User account
Unlock-ADAccount -Identity "User02"

#More than one Filter conditions
#And Operator Filter: -Filter {(Name -Like "") -And (Department -eq "")}
#OR Operator Filter: -Filter {(Name -Like "") -OR (Department -eq "")}
#Finding a user from certain department and name.
Get-ADUser -Filter {(department -eq "IT") -and (Name -eq "User01")}  -Properties Department| Select Name, Department |Format-Table -AutoSize
Get-ADUser -Filter {(department -eq "IT") -and (Name -like "User*")} -Properties Department| Select Name, Department |Format-Table -AutoSize
#Find a user in IT Dept who are enabled.
Get-ADUser -Filter {(department -eq "IT") -and (Enabled -eq $True)}| Select Name, Enabled |Format-Table -AutoSize
Get-ADUser -Filter {(department -eq "IT") -and (Enabled -eq $False)}| Select Name, Enabled |Format-Table -AutoSize
#Find AD users with AD Attibutes, like Telephone Number, Email., etc
#Use Properties : -Properties 
Get-ADUser -Identity "User02" -Properties TelephoneNumber| Select Name, TelephoneNumber |Format-Table -AutoSize
#Find users with Certain Properties in OU like Telephone Number
Get-ADUser -Filter * -SearchBase "OU=FFOUsers,DC=local,DC=dc" -Properties TelephoneNumber `
| where {$_.TelephoneNumber -match "121*"}| Select Name,TelephoneNumber|Format-Table -AutoSize
#Find users with Certain Properties in OU like Mail
Get-ADUser -Filter * -SearchBase "OU=FFOUsers,DC=local,DC=dc" -Properties Mail | where {$_.Mail -match "user*"}| `
Select Name,Mail|Format-Table -AutoSize
#Check the User Password Last Set and Password Never Expires flag.
Get-ADUser -Identity "User01" -properties PasswordLastSet, PasswordNeverExpires `
 | Select Name, PasswordLastSet, PasswordNeverExpires|Format-Table -AutoSize
#Check the user if Password had Expired.
Get-ADUser -filter 'PasswordExpired -eq $True' -SearchBase "OU=FFOUsers,DC=local,DC=dc"
#Check the AD User when the password would expire
Get-ADUser -filter * -SearchBase "OU=FFOUsers,DC=local,DC=dc" –Properties "DisplayName", "msDS-UserPasswordExpiryTimeComputed"`
| Select-Object -Property "Displayname",@{Name="ExpiryDate";Expression={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}}`
|Format-Table -AutoSize