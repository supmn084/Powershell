$report = @()

$a = "<style>"
$htmlbody = "<H2>This is my Body<br>Last update: $(get-date) </H2>"
$a = "<style>BODY{background-color:#D8D8D8;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 10px;border-style: solid;border-color: black;background-color:#A9D0F5}"
$a = $a + "TD{border-width: 1px;padding: 10px;border-style: solid;border-color: black;background-color:#E0ECF8}"
$a = $a + "</style>"


$obj = New-Object System.Object
$obj | Add-Member -MemberType NoteProperty -Name Chassis -Value "MyChassis"
$obj | Add-Member -MemberType NoteProperty -Name Bay -Value "Bay1"


$report += $obj

# Get-Service | Select-Object Status, Name, DisplayName | ConvertTo-HTML -head $a -Body $htmlbody | Out-File C:\temp\Test.htm
$report | ConvertTo-HTML -head $a -Body $htmlbody | Out-File C:\temp\Test.html


