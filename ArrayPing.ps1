$mylist = "google.com","visa.com","mastercard.com"

write-host("Pinging Server in my test list")
foreach ($element in $myList) {
  ping $element
}

