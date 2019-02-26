#
# Version 1.1
#
function get-spListItems {
<#
	.SYNOPSIS
	 Connects to the web service and does a mass download of the list
	 Output a list object
	
	.EXAMPLE
	
	import-module \\dcfile1\systems\scripts\Modules\csgp-sharepointws\csgp-sharepointws.psm1 -force
	$uri = 'http://dcappprd158/sandbox/_vti_bin/lists.asmx?wsdl'
	$listName = 'Cars'
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	$listRows = get-spListItems -listName $listName -service $service 
	
	.NOTES
	Columns missing when using the Lists.GetListItems SharePoint web service
	http://pholpar.wordpress.com/2009/06/11/columns-missing-when-using-the-lists-getlistitems-sharepoint-web-service/
	#>
[cmdletBinding()]
	param(
		# The name of the sharepoint list
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		[string]$listName,
		# The web service variable
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$service
	)
	$xmlDoc = new-object System.Xml.XmlDocument
	$query = $xmlDoc.CreateElement("Query")
	$viewFields = $xmlDoc.CreateElement("ViewFields")
	$queryOptions = $xmlDoc.CreateElement("QueryOptions")
	$rowLimit = "0"

	$listObj = $service.GetListItems($listName, "" , $query, $viewFields, $rowLimit, $queryOptions, "")
	Write-Output  $listObj.data.row
}

function new-spListItem {	
	<#
	.SYNOPSIS
	Add new list item via sharepoint web services
	
	.EXAMPLE
	
	import-module \\dcfile1\systems\scripts\Modules\csgp-sharepointws\csgp-sharepointws.psm1 -force
	$uri = 'http://dcappprd158/sandbox/_vti_bin/lists.asmx?wsdl'
	$listName = 'Cars'
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	
	$xmlFields = @"
			"<Field Name='Title'>Porche</Field>" 
	    	"<Field Name='Model'>911</Field>" 		
			"<Field Name='Color'>White</Field>"		
"@
	new-spListItem -listName $listName -xmlFields $xmlFields -service $service
	
	.NOTES
	Note: to update Choice->Checkboxes "<Field Name='ComputerType'>;#Virtual;#Physical;#</Field>"
	It seems for all choice fields except for checkboxes you just specify the value and the 
	sharepoint field will match that to the choice list
	
	#>

[cmdletBinding()]
	param(
		# The string list name
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$listName,
		# You create the $xmlfields similar to the example in this function
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$xmlFields,
		# The web service
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$service
	)
	
		# Metadata for list updates
	#
	# Get name attribute values (guids) for list and view            
	$ndlistview = $service.getlistandview($listname, "")            
	$strlistid = $ndlistview.childnodes.item(0).name            
	$strviewid = $ndlistview.childnodes.item(1).name            
	# Create an xmldocument object and construct a batch element and its     attributes.             
	$xmldoc = new-object system.xml.xmldocument             
	# note that an empty viewname parameter causes the method to use the default view               
	$batchelement = $xmldoc.createelement("Batch")            
	$batchelement.setattribute("onerror", "continue")            
	$batchelement.setattribute("listversion", "1")            
	$batchelement.setattribute("viewname", $strviewid)    

	# Specify methods for the batch post using caml. 
	#	to update or delete, specify the id of the #item,
	#	and to update or add, specify the value to place in the specified column            
    $xml = ""            
 
	$xml += "<Method ID='1' Cmd='New'>" +
	    	$xmlFields +
    		"</Method>" 


	# Set the xml content                    
	$batchelement.innerxml = $xml            
	$ndreturn = $null             
	try {            
	    $ndreturn = $service.updatelistitems($listname, $batchelement)             
	}            
	catch {             
	    write-error $_ -erroraction:'stop'            
	}

}

function update-spListItem {	
	<#
	.SYNOPSIS
	Update individual items based on rowID
	
	.EXAMPLE
	
	import-module \\dcfile1\systems\scripts\Modules\csgp-sharepointws\csgp-sharepointws.psm1 -force
	$uri = 'http://dcappprd158/sandbox/_vti_bin/lists.asmx?wsdl'
	$listName = 'Cars'
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	$listRows = get-spListItems -listName $listName -service $service 
	$myCarRow = $listrows | ? {$_.ows_title -eq 'Infiniti' }
	
	$xmlFields = @"
			"<Field Name='Title'>Infiniti</Field>" 
	    	"<Field Name='Model'>G37x</Field>" 		
			"<Field Name='Color'>White</Field>"		
"@
	update-spListItem -listName $listName -rowID $myCarRow.ows_id -xmlFields $xmlFields -service $service
	
	.NOTES
	Note: to update Choice->Checkboxes "<Field Name='ComputerType'>;#Virtual;#Physical;#</Field>"
	It seems for all choice fields except for checkboxes you just specify the value and the 
	sharepoint field will match that to the choice list

	#>

[cmdletBinding()]
	param(
		# The sharepoint list name
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$listName,
		# The row ID from $listitems.  ows_ID
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$rowID,
		# You create the $xmlfields similar to the example in this function
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$xmlFields,
		# The web service
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$service
	)
	#
	# Metadata for list updates
	#
	# Get name attribute values (guids) for list and view            
	$ndlistview = $service.getlistandview($listname, "")            
	$strlistid = $ndlistview.childnodes.item(0).name            
	$strviewid = $ndlistview.childnodes.item(1).name            
	# Create an xmldocument object and construct a batch element and its     attributes.             
	$xmldoc = new-object system.xml.xmldocument             
	# note that an empty viewname parameter causes the method to use the default view               
	$batchelement = $xmldoc.createelement("Batch")            
	$batchelement.setattribute("onerror", "continue")            
	$batchelement.setattribute("listversion", "1")            
	$batchelement.setattribute("viewname", $strviewid)    

	# Specify methods for the batch post using caml. 
	#	to update or delete, specify the id of the #item,
	#	and to update or add, specify the value to place in the specified column            
    $xml = ""            
 
	
	$xml += "<Method ID='1' Cmd='Update'>" +
			    "<Field Name='ID'>$rowID</Field>" +
		    	$xmlFields +
	    		"</Method>"  
	# Set the xml content                    
	$batchelement.innerxml = $xml            
	$ndreturn = $null             
	try {            
	    $ndreturn = $service.updatelistitems($listname, $batchelement)             
	}            
	catch {             
	    write-error $_ -erroraction:'stop'            
	}

}

function remove-spListItem {	
	<#
	.SYNOPSIS
	Remove individual item based on rowID
	.EXAMPLE
	import-module \\dcfile1\systems\scripts\Modules\csgp-sharepointws\csgp-sharepointws.psm1 -force
	$uri = 'http://dcappprd158/sandbox/_vti_bin/lists.asmx?wsdl'
	$listName = 'Cars'
	# create the web service
	$service = New-WebServiceProxy -UseDefaultCredential -uri $uri
	$listRows = get-spListItems -listName $listName -service $service 
	$myCarRow = $listrows | ? {$_.ows_title -eq 'Infiniti' }
	
	remove-spListItem -listName $listName -rowID $myCarRow.ows_ID -service $service
	
	.NOTES
	Note: to update Choice->Checkboxes "<Field Name='ComputerType'>;#Virtual;#Physical;#</Field>"
	It seems for all choice fields except for checkboxes you just specify the value and the 
	sharepoint field will match that to the choice list
	
	#>

[cmdletBinding()]
	param(
		# The string sharepoint list name
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		[string]$listName,
		# The individual ows_ID
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$rowID,
		# The web service
		[Parameter(Mandatory=$True,ValueFromPipeline=$true)] # Required and accepts pipeline input
		$service
	)
	#
	# Metadata for list updates
	#
	# Get name attribute values (guids) for list and view            
	$ndlistview = $service.getlistandview($listname, "")            
	$strlistid = $ndlistview.childnodes.item(0).name            
	$strviewid = $ndlistview.childnodes.item(1).name            
	# Create an xmldocument object and construct a batch element and its     attributes.             
	$xmldoc = new-object system.xml.xmldocument             
	# note that an empty viewname parameter causes the method to use the default view               
	$batchelement = $xmldoc.createelement("Batch")            
	$batchelement.setattribute("onerror", "continue")            
	$batchelement.setattribute("listversion", "1")            
	$batchelement.setattribute("viewname", $strviewid)    

	# Specify methods for the batch post using caml. 
	#	to update or delete, specify the id of the #item,
	#	and to update or add, specify the value to place in the specified column            
    $xml = ""            
 
	
	$xml += "<Method ID='1' Cmd='Delete'>" +
			    "<Field Name='ID'>$rowID</Field>" +
	    		"</Method>"  
	# Set the xml content                    
	$batchelement.innerxml = $xml            
	$ndreturn = $null             
	try {            
	    $ndreturn = $service.updatelistitems($listname, $batchelement)             
	}            
	catch {             
	    write-error $_ -erroraction:'stop'            
	}

}
