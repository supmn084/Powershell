# http://html-color-codes.info/


$html_output = "c:\temp\test.html"
# $votes = "" | Select-Object v1,v2,v3,v4
$names = @("Ben", "Lucy", "Jackie")
$db = @()

$htmlbody = "<H2>Reston Chassis-to-Blade Mappings<br>Last update: $(get-date) </H2>"
$a = "<style>BODY{background-color:#D8D8D8;}"
$a = $a + "TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#A9D0F5}"
$a = $a + "TD{border-width: 1px;padding: 0px;border-style: solid;border-color: black;background-color:#E0ECF8}"
$a = $a + "</style>"

foreach ($name in $names)	{
	$obj = New-Object System.Object
	$obj | Add-Member -MemberType NoteProperty -Name FirstName -Value $name
	$db += $obj
}

$db | ConvertTo-Html -Property Firstname -Head $a -Body $htmlbody | Out-File  $html_output
