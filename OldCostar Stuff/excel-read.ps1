$input = "\\Dcfile1\systems\Projects\Storage_Area_Network\Projects\2010 - Remap switch ports for colo move\test1.xlsx"

$before = @(Get-Process [e]xcel | %{$_.Id})
$Excel = New-Object -COM Excel.Application
$ExcelId = Get-Process excel | %{$_.Id} | ?{$before -notcontains $_}
$Excel.visible = $False
$Workbook = $Excel.Workbooks.Open($input) 

# select which sheet you want to edit
write-host "Numer of worksheets: " $Workbook.Sheets.Count
$WorkSheet = $WorkBook.Worksheets.Item(1)

$row = 1
$col = 1
$sheet = 1

write-host $($WorkSheet.Cells.Item(1,1).Value())

$Excel.Quit()
$WorkBook = $Null
$WorkSheet = $Null
$Excel = $Null
[GC]::Collect()
Stop-Process -Id $ExcelId -Force -ErrorAction SilentlyContinue
