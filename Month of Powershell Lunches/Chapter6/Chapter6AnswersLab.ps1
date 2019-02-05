#### 1
"I am the walrus" |out-file file1.txt.
"I am a beliver" |Out-File file2.txt
$f1=Get-Content .\file1.txt
$f2=Get-Content .\file2.txt
diff $f1 $f2
####2
## If you don't specify a filename with out-file you'll get an error, the file is created by Export-Csv ##
##3
#yes stop-service and pick the name
#4
Get-Service |Export-Csv services.csv -Delimiter "|"
#5
-notypeinformation
#6
Get-Service |Export-Csv services.csv -NoClobber
Get-Service |Export-Csv services.csv -Confirm
#7
Get-Service |Export-Csv services.csv -UseCulture