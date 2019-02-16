$myList = 5.6, 4.5, 3.3, 13.2, 4.0, 34.33, 34.0, 45.45, 99.993, 11123

write-host("Print all the array elements")
$myList

write-host("Get the length of array")
$myList.Length

write-host("Get Second element of array")
$myList[1]

write-host("Get partial array")
$subList = $myList[1..3]

write-host("print subList")
$subList

write-host("using for loop")
for ($i = 0; $i -le ($myList.length - 1); $i += 1) {
  $myList[$i]
}

write-host("using forEach Loop")
foreach ($element in $myList) {
  $element
}

write-host("using while Loop")
$i = 0
while($i -lt 4) {
  $myList[$i];
  $i++
}

write-host("Assign values")
$myList[1] = 10
$myList


$myList = @(0..4)

write-host("Print array")
$myList

$myList = @(0..4)

write-host("Assign values")
$myList[1]  = 10
$myList