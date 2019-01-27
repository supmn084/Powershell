#$input = "\\Dcfile1\systems\Projects\Storage_Area_Network\Projects\2010 - Remap switch ports for colo move\test1.xlsx"
#$output = "\\Dcfile1\systems\Projects\Storage_Area_Network\Projects\2010 - Remap switch ports for colo move\test1.csv"
$input = "http://dcappprd128:4444/sites/ProjectPortal/IT/dcdatacentermove/Shared%20Documents/Technical%20Documents/Blade%20Server%20Locations%20Before%20and%20After.xlsx"
$output = "c:\temp\test1.csv"

$xlCSV=6


$before = @(Get-Process [e]xcel | %{$_.Id})
$Excel = New-Object -COM Excel.Application
$ExcelId = Get-Process excel | %{$_.Id} | ?{$before -notcontains $_}
$Excel.visible = $False
$Workbook = $Excel.Workbooks.Open($input) 

$Workbook.SaveAs($output,$xlCSV)

$WorkBook = $Null
$WorkSheet = $Null
$Excel = $Null
[GC]::Collect()
Stop-Process -Id $ExcelId -Force -ErrorAction SilentlyContinue
