#--------------------------------Sharepoint 2010 Portal Builder-------------------------------------------------------
#
#	Description: 		I created this script as an effort to deploy an entire site structure 
#						into a DEV and QA (and potentially PROD) environment up and running quick. 
#						I also wanted something I could easily edit on the fly.
#
#						This script includes the following functions:
#
#						- Creating Web Application
#						- Creating Site Collections
#						- Creating Subsites
#						- Setting Master Pages recursively.
#						- Adding Features
#						- Adding Site Columns
#						- Creating Lists 
#						- Adding folders to Lists
#						- Adding Site Column to Lists
#						- Creating Views
#						- Enabling/Disabling Publishing, Checkin, and Approvals
#						- Creating Sample Items for Links, Announcements, and Calendar lists with permissions.
#						- Creating Publishing Pages
#						- Creating Groups with default owners
#						- Set Group permissions for subsites
#						- Add Content Query Web Parts (CQWP) for site and subsite lists.
#
#	Tools:				You can easily use Notepad to edit this file, but I highly recommend PowerGUI. 
#						It it is free and has a great interface and provides things like debugging, Intellisense, formatting, 
#						and plug-ins.	Power GUI:	http://www.powergui.org
#
#	Developer Notes:	I am not a PowerShell pro by any stretch of imagination and am still learning the intricacies of the language.
#						There is no use of classes, collections, and exception handling is sparse. Some of this is due to my ingorance
#						on the subject. That being said, I have no doubt there are areas that can be written more efficiently.
#
#	Author:				John Livingston
#	E-mail:				jmlivingston@gmail.com
#	Website:			http://johnlivingstontech.blogspot.com
#	Created Date:		2/1/2011
#	Updated Date:		2/1/2011
#
#--------------------------------CreateSamplePublishingPortal Function-------------------------------------------------------
#
#	Description:		This function will use all of the scripts functions and create an entire web application and site collection
#						with subsites, site columns, lists, sample list items, and permissions. You can easily comment out or change 
#
#	Parameters:			If you choose false for either, ensure that all of the variables in the function are correct.
#						$createWebApplication - Boolean to determine if Web Application is created.
#						$createSiteCollection - Boolean to determine if Site Collection is created.
#						$env - Determines the environment. Valid values are: "dev", "qa", or "prod". 
#						Variables within the function must be updated to use this functionality.
#
#	Global Variables:	Before running the script, you will want to make sure and update all Global Variabes in this script
#						to ensure they will work with your environment. You can also comment out parts of the script that you don't want to run.
#
#	Lists:				-	The multichoice "Site Visibility" site column is added to all lists. It include the values 
#							"Private Team", "Public Team", and "Intranet".
#						-	Corresponding views are created for each "Site Visibility" value.
#						-	A "public" folder added to each list and read permissions added to allow users outside of the private site.
#						-	Sample items are also added to the lists and every combination of "Site Visibility" is used. If the 
#							value for the item has a "Site Visibility" that contains "Public Team" or "Intranet" it is moved into the "public" folder.
#							This allows permissions to stay at the folder level and not the item level. 
#						-	Note: A workflow still needs to be created
#							to ensure that when items are created or changed they go to the public folder.
#
#	Permissions:		All departmental private team sites disinherit the top level permissions so that unique permissions can be created.
#						For example, Human Resources would include the following groups:
#					
#						Group Name		Permission
#						HR Owners		Full Control
#						HR Members		Contribue
#						HR Visitors		Read
#
#						The script also applies a default owner for all groups. This is an array variable that can be updated before running the script.
#						
#	Aggregate Views:	Aggregate views using Content Query Web Parts (CQWP) are added to the Intranet and Public departmental team sites.
#						and aggregate views CQWP that use list views
#						created from the private team sites.
#						It also does a few extra things like disabling publishing and approval, changing master page to v4.master, 
#						enabling Team Collaboration Features.
#
#	Extras:				The script also does a few extra things like disabling publishing and approval, changing master page to v4.master, 
#						enabling Team Collaboration Features. I did this for a little more flexibility, especially for DEV and QA mode.
#						These can all be easily disabled or changed back by using one of the functions in this file. For example, if you already
#						have a web application, you can comment out "CreateWebApplication".
#
#	Execution Time:		My notebook is not virtual, has an Intel i7 an 8 GB RAM. It takes around 8 minutes to run the entire script. Of that 8 minutes.
#						Rough creation times (in seconds): Web Applicatoin: 110 s. / Site collection: 75 s. / Site: 30 s. 
#
#
#	Site Hierarchy:		The following site hierarchy is created with this function. 
#						You can easily change this hierarchy by updating the variables in the function.
#
#		Intranet								Web Application
#		Intranet								Site Collection		*(See notes below)
#			Departments							Publishing Site
#				Private							Publishing Site
#					Finance						Publishing Site
#						Announcements			Announcements List
#						News					News List
#						Team Calendar			Calendar
#						I Want To				Links List
#						Staff Roles				Publishing Page
#						Training				Publishing Page
#						New Hires				Publishing Page
#					Human Resources				Publishing Site
#						Announcements			Announcements List
#						News					News List
#						Team Calendar			Calendar
#						I Want To				Links List
#						Staff Roles				Publishing Page
#						Training				Publishing Page
#						New Hires				Publishing Page
#					Information Technology		Publishing Site
#						Announcements			Announcements List
#						News					News List
#						Team Calendar			Calendar
#						I Want To				Links List
#						Staff Roles				Publishing Page
#						Training				Publishing Page
#						New Hires				Publishing Page
#					Marketing					Publishing Site
#						Announcements			Announcements List
#						News					News List
#						Team Calendar			Calendar
#						I Want To				Links List
#						Staff Roles				Publishing Page
#						Training				Publishing Page
#						New Hires				Publishing Page
#				Public							Publishing Site
#					Finance						Publishing Site		**(See notes below)
#					Human Resources				Publishing Site		**(See notes below)
#					Information Technology		Publishing Site		**(See notes below)
#					Marketing					Publishing Site		**(See notes below)
#	
#	*	Intranet Home page includes CQWPs that point to Lists from all departmental Private departmental sites.
#		These are filtered by "Site Visibility" column where the value contains "Intranet".
#
#	**	TODO: Departmental Public Home page includes CQWPs that aggregate Lists from corresponding Private departmental site.
#		These are filtered by "Site Visibility" column where the value contains "Public Team".

function CreateWebApplication ($webApplicationName, $appPoolUserName, $appPoolPassword, $portNumber, $serverName, $timeZoneId) 
{
	#--------------CONCATENATED VARIABLES (UPDATE FORMAT IF NECESSARY)-----------------
	$appPoolName = $webApplicationName + "_AppPool"									##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$databaseServer = $webApplicationName + "_ContentDB"							##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$rootDirectory = "C:\Inetpub\wwwroot\wss\VirtualDirectories\" + $portNumber		##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	#--------------CREATING WEB APP-----------------
	Write-Host "Creating Web Application - "$webApplicationName
	$farm = [microsoft.sharepoint.administration.spfarm]::local
	$WebAppBuilder = new-object microsoft.sharepoint.administration.SPWebApplicationBuilder($farm)
	$WebAppBuilder.ApplicationPoolId = $appPoolName
	$WebAppBuilder.ApplicationPoolUsername = $appPoolUserName
	$WebAppBuilder.ApplicationPoolPassword = $appPoolPassword
	$WebAppBuilder.IdentityType = [Microsoft.SharePoint.Administration.IdentityType]::SpecificUser
	$WebAppBuilder.Port = $portNumber
	$WebAppBuilder.ServerComment = $webApplicationName
	$WebAppBuilder.CreateNewDatabase = $true
	$WebAppBuilder.DatabaseServer = $serverName
	$WebAppBuilder.DatabaseName = $databaseServer
	$WebAppBuilder.RootDirectory = $rootDirectory
	$WebAppBuilder.UseSecureSocketsLayer = $false
	$WebAppBuilder.AllowAnonymousAccess = $false
	$webapp = $WebAppBuilder.Create()
	$webapp.ProvisionGlobally()
	$webapp.DefaultTimeZone = $timeZoneId
	$webapp.Update()
	Write-Host "Finished Creating Web Application - "$webApplicationName
}

function CreateSiteCollection($siteName, $siteUrl, $siteOwner, $siteTemplate, $removeLibraryApprovalWorkflow, $disableCheckoutModeration, $addTeamCollaborationFeature)
{
	Write-Host "Creating Site Collection - "$siteName
	New-SPSite -Name $siteName -Url $siteUrl -OwnerAlias $siteOwner -Template $siteTemplate
	Write-Host "Finished Creating Site Collection - "$siteName	
	if($disableCheckoutModeration)
	{
		EnableMasterPageModerationCheckout $siteUrl $disableCheckoutModeration
	}
	if($removeLibraryApprovalWorkflow)
	{
		$listNames = @("Pages", "Documents", "Images") #Publishing Site Default Lists
		RemoveApprovalWorkflows $siteUrl "" $listNames "Page Approval"
	}	
	if($addTeamCollaborationFeature)
	{
		$teamCollaborationGuid = New-Object System.Guid("00bfea71-4ea5-48d4-a4ad-7ea5c011abe5") #Team Collaboration Feature (Allows for more content types)
		AddWebFeature $siteUrl "" $teamCollaborationGuid
	}	
}

function CreateWeb($siteUrl, $webUrl, $mappedPath, $webName, $webOwner, $webTemplate, $removeLibraryApprovalWorkflow, $addTeamCollaborationFeature)
{
	Write-Host "Creating Web - "$webName
	New-SPWeb -Name $webName -Url ($siteUrl+$webUrl) -Template $webTemplate
	if($removeLibraryApprovalWorkflow)
	{
		$listNames = @("Pages", "Documents", "Images") #Publishing Site Default Lists
		if($removeLibraryApprovalWorkflow)
		{
			RemoveApprovalWorkflows $siteUrl $webRelativeUrl $listNames "Page Approval"
		}		
		if($addTeamCollaborationFeature)
		{
			$teamCollaborationGuid = New-Object System.Guid("00bfea71-4ea5-48d4-a4ad-7ea5c011abe5") #Team Collaboration Feature (Allows for more content types)
			AddWebFeature $siteUrl ($mappedPath+$webUrl) $teamCollaborationGuid
		}
	}
	Write-Host "Finished Creating Web - "$webName
}

function AddWebFeature($siteUrl, $webUrl, $featureGuid)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{				
		    $web.Features.Add($featureGuid)
			Write-Host "Finished Adding Feature - ("+$featureGuid+") "+$siteUrl$webUrl
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Creating List - "$listName "for" $webUrl
}

function AddContentByQueryWebPart($siteUrl, $webPartSourceWebUrl, $webPartWebUrl, $queryListWebUrl, $webPartPageUrl, $queryListName, $webPartTitle, $filterField, $filterValue, $filterDisplayValue, $itemLimit, $zoneId, $zoneIndex)
{
    $listId = ""
    try 
    {
		$site = Get-SPSite $siteUrl
		try
		{
        	$web = $site.OpenWeb($queryListWebUrl)
            $list = $web.Lists[$queryListName]			
			$listId = $list.ID
		}
		finally
		{
			$web.Dispose()
		}			
		try
		{
        	$web = $site.OpenWeb($webPartSourceWebUrl)
            $web.AllowUnsafeUpdates = $true
            $file = $web.GetFile($webPartPageUrl)			
			try
			{
				$list = $web.Lists["Pages"]
				if($list.ForceCheckout -eq $true)
				{
					$file.CheckOut()
					$file.Update()
				}	
            	$mgr = $file.GetLimitedWebPartManager([System.Web.UI.WebControls.WebParts.PersonalizationScope]::Shared)
                $cqwp = New-Object Microsoft.SharePoint.Publishing.WebControls.ContentByQueryWebPart
                $cqwp.DisplayColumns = 1
                $cqwp.FeedEnabled = $false
                $cqwp.Filter1ChainingOperator = 0#Microsoft.SharePoint.Publishing.WebControls.ContentByQueryWebPart.FilterChainingOperator.And
                $cqwp.Filter1IsCustomValue = $false
                $cqwp.FilterByAudience = $false
                $cqwp.FilterDisplayValue1 = $filterDisplayValue
                $cqwp.FilterField1 = $filterField
                $cqwp.FilterIncludeChildren1 = $false				
                $cqwp.FilterOperator1 = "Contains"#1#Microsoft.SharePoint.Publishing.WebControls.ContentByQueryWebPart.FilterFieldQueryOperator.Contains
                $cqwp.FilterType1 = "MultiChoice"
                $cqwp.FilterValue1 = $filterValue
                $cqwp.GroupByDirection = 1#Microsoft.SharePoint.Publishing.WebControls.ContentByQueryWebPart.SortDirection.Desc
                $cqwp.GroupStyle = "DefaultHeader"
                $cqwp.ItemLimit = $itemLimit
                $cqwp.ItemStyle = "Default"
                $cqwp.ListGuid = $listId
                $cqwp.ListName = $queryListName
                $cqwp.PlayMediaInBrowser = $true
                $cqwp.ServerTemplate = "104"
                $cqwp.ShowUntargetedItems = $false
                $cqwp.SortBy = "Created"
                $cqwp.SortByDirection = 1#Microsoft.SharePoint.Publishing.WebControls.ContentByQueryWebPart.SortDirection.Desc
                $cqwp.SortByFieldType = "DateTime"
                $cqwp.Title = $webPartTitle
                $cqwp.UseCache = $true
                $cqwp.UseCopyUtil = $true
                $cqwp.WebUrl = $webPartWebUrl
                $mgr.AddWebPart($cqwp, $zoneId, $zoneIndex) 
				if($list.ForceCheckout -eq $true)
				{
					$file.Update()
					$file.CheckIn("")
					$file.Publish("")
					$file.Approve("")					
				}
				$web.Update()
				Write-Host "Finished Adding Content Query Web Part - "$siteUrl$webPartWebUrl" from "$queryListWebUrl "("$queryListName")"
			}
			finally
			{
				$mgr.Dispose()
			}
        }			
		finally
		{
			$web.Dispose()
		}			
    }
	finally
	{
		$site.Dispose()
	}
}

function CreateList($siteUrl, $webUrl, $listName, $listDescription, $listTemplate)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
		    $web.Lists.Add($listName, $listDescription, $listTemplate)
			$web.Update()
			Write-Host "Finished Creating List - "$webUrl"/"$listName
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Creating List - "$listName "for" $webUrl
}

function AddListFolder($siteUrl, $webUrl, $listName, $folderName, $isList)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
            $list = $web.Lists[$listName]
			if($isList)
			{				
				$folder = $list.Items.Add($list.RootFolder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::Folder, $folderName)
			}
			else			
			{
            	$folder = $list.RootFolder.SubFolders.Add($folderName).Item
			}
			if(!($folder.ModerationInformation -eq $null))
			{
            	$folder.ModerationInformation.Status = [Microsoft.SharePoint.SPModerationStatusType]::Approved
			}
            $folder.Update()
			Write-Host "Finished Creating Folder - "$folderName" on "$siteUrl$webUrl"/"$listName"/"
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function AddListSiteColumn($siteUrl, $webUrl, $listName, $fieldName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
           	$list = $web.Lists[$listName]
            $field = $site.RootWeb.Fields[$fieldName]		
			$list.Fields.Add($field)
			$list.Update()
			$view = $list.DefaultView
			$view.ViewFields.Add($fieldName)
			$view.Update()
			Write-Host "Finished Adding Site Column - "$fieldName" to "$siteUrl$webUrl"/"$listName"/"
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function AddListView($siteUrl, $webUrl, $listName, $viewName, $fieldNames, $camlQuery, $rowLimit, $paged, $defaultView, $showFolders)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
            $list = $web.Lists[$listName]
            $colViews = $list.Views
            $collViewFields = New-Object System.Collections.Specialized.StringCollection
			foreach($fieldName in $fieldNames)
			{
            	$collViewFields.Add($fieldName)
			}
            $strQuery = ($camlQuery)
            $colViews.Add($viewName, $collViewFields, $strQuery, $rowLimit, $paged, $defaultView)
			if($showFolders -eq $false)
			{
				$view = $list.Views[$viewName]
				$view.Scope = [Microsoft.SharePoint.SPViewScope]::Recursive
				$view.Update()
			}			
			Write-Host "Finished Adding List View - "$viewName" to "$siteUrl$webUrl"/"$listName"/"
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function SetListFolderPermissions($siteUrl, $webUrl, $listName, $folderName, $groupName, $roleDefinition)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
            $list = $web.Lists[$listName]
            $folder = $list.RootFolder.SubFolders[$folderName].Item
            $folder.BreakRoleInheritance($true)
            $web.AllowUnsafeUpdates = $true
            $group = $web.SiteGroups[$groupName]			
            $roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
            $roleAssignment.RoleDefinitionBindings.Add($web.RoleDefinitions[$roleDefinition])
            $folder.RoleAssignments.Add($roleAssignment)
            $folder.Update()
			Write-Host "Finished Adding Permissions to folder "$folderName" on "$siteUrl$webUrl"/"$listName" ("$groupName" - "$roleDefinition")"
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function CreateSiteColumnMultiChoice($siteUrl, $fieldName, $fieldChoices, $defaultValue, $group, $required)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb()
		try
		{		
			$web.Fields.Add($fieldName, [Microsoft.SharePoint.SPFieldType]::MultiChoice, $required)
            $field = $web.Fields[$fieldName]
            foreach($fieldChoice in $fieldChoices)
			{
				$field.Choices.Add($fieldChoice)
			}            
			$field.DefaultValue = $defaultValue
            $field.Group = $group
            $field.Update()
			Write-Host "Finished Adding Site Column ("$fieldName") to web "$siteUrl
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function SetRoleInheritance($siteUrl, $webUrl, $breakInheritance)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
			if($breakInheritance)
			{
		    	$web.BreakRoleInheritance($breakInheritance)
			}
			else
			{
				$web.ResetRoleInheritance()
			}
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Setting Inheritance - "$siteUrl$webUrl	" (Break Inheritance - "$breakInheritance")"
}

function AddSiteGroup($siteUrl, $groupName, $defaultUser, $ownerGroup, $description)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb()
		try
		{	
			$web.SiteGroups.Add($groupName, $web.SiteGroups[$ownerGroup], $web.SiteUsers[$defaultUser], $description) 
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Adding Site Group - "$groupName" to "$siteUrl	
}

function AddGroupPermission($siteUrl, $webUrl, $groupName, $roleDefinitionName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
			$web.AllowUnsafeUpdates = $true
			$group = $site.RootWeb.SiteGroups[$groupName]
            $roleAssignment = New-Object Microsoft.SharePoint.SPRoleAssignment($group)
			$roleDefinition = $site.RootWeb.RoleDefinitions[$roleDefinitionName]
            $roleAssignment.RoleDefinitionBindings.Add($roleDefinition)
            $web.RoleAssignments.Add($roleAssignment)
			$web.Update()
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Adding Group Permission - "$groupName "("$roleDefinitionName") to "$siteUrl$webUrl	
}

function RemoveGroupPermission($siteUrl, $webUrl, $groupName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
			$web.AllowUnsafeUpdates = $true
			$group = $site.RootWeb.SiteGroups[$groupName]
            $web.RoleAssignments.Remove($group)
			$web.Update()
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
	Write-Host "Finished Removing Group Permission - "$groupName "from" $siteUrl$webUrl	
}

function CreatePublishingPage($siteUrl, $webUrl, $pageFileName, $pageName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
		    $publishingWeb = [Microsoft.SharePoint.Publishing.PublishingWeb]::GetPublishingWeb($web)
		    $pageLayouts = $publishingWeb.GetAvailablePageLayouts()
		    $currPageLayout = $pageLayouts[0]
		    $pages = $publishingWeb.GetPublishingPages()
		    $newPage = $pages.Add($pageFileName, $currPageLayout)
			$newPage.Title = $pageName
		    $newPage.Update()
		    $newPage.CheckIn("")			
			$newPage.ListItem.File.Approve("")			
			Write-Host "Finished Creating Page - "$pageName "for" $webUrl
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function RemoveApprovalWorkflows($siteUrl, $webUrl, $listNames, $workFlowName)
{
	foreach($listName in $listNames)
	{
		RemoveApprovalWorkflow $siteUrl $webUrl $listName $workFlowName
	}	
}

function RemoveApprovalWorkflow($siteUrl, $webUrl, $listName, $workFlowName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
			$list = $web.Lists[$listName]
			if(!($list -eq $null))
			{
				$wa = $list.WorkflowAssociations.GetAssociationByName($workFlowName, [System.Globalization.CultureInfo]::CurrentCulture)	
				if(!($wa -eq $null))
				{	
					Write-Host "Removing" $wa.Name "from" $listName
					$list.WorkflowAssociations.Remove($wa)
					Write-Host "Finished Removing Workflow "$workFlowName" from "$siteUrl$webUrl"/"$listName
				}	
			}	
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function AddApprovalWorkflow($siteUrl, $webUrl, $listName, $workflowTemplateName, $workflowName, $workflowTaskName, $workflowHistoryName)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{		
			$list = $web.Lists[$listName]
			if(!($list -eq $null))
			{
				$wfTemp = $web.WorkflowTemplates.GetTemplateByName($workflowTemplateName, [System.Globalization.CultureInfo]::CurrentCulture);
				$wf = [Microsoft.SharePoint.Workflow.SPWorkflowAssociation]::CreateListAssociation($wfTemp, $workflowName, $web.Lists[$workflowTaskName], $web.Lists[$workflowHistoryName]);
				$list.WorkflowAssociations.Add($wf)
				$list.DefaultContentApprovalWorkflowId = $wf.Id
				$list.Update()
				Write-Host "Finished Adding Workflow "$workflowTemplateName" to "$siteUrl$webUrl"/"$listName
			}
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}	
}

function EnableMasterPageModerationCheckout($siteUrl, $enable)
{
	$site = Get-SPSite $siteUrl
	try
	{		
		$list = $site.GetCatalog([Microsoft.SharePoint.SPListTemplateType]::MasterPageCatalog)
		$list.EnableModeration = $enable
		$list.ForceCheckout = $enable
		$list.Update()
		Write-Host "MasterPage Moderation and Checkout on "$siteUrl" set to "$enable
	}
	finally
	{
		$site.Dispose()
	}
}

function UpdateMasterPageUrl($siteUrl, $webUrl, $masterPageUrl, $inheritMasterPage)
{
	$site = Get-SPSite $siteUrl
	try
	{
		$web = $site.OpenWeb($webUrl)
		try
		{	
			$web.CustomMasterUrl = $masterPageUrl
			if(!($web -eq $null))
			{
				if($inheritMasterPage)
				{
					$web.AllProperties["__InheritsCustomMasterUrl"] = "True";
					
				}
				else
				{
					$web.AllProperties["__InheritsCustomMasterUrl"] = "False";	
				}
			}
			Write-Host "MasterPage Updated for "$siteUrl"/"$webUrl" (Custom URL:"$masterPageUrl" / Inheritance:"$inheritMasterPage")"
			$web.Update()
		}
		finally
		{
			$web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}
}

function AddSampleAnnouncements($siteUrl, $webUrl, $webName, $listName)
{
    $title = "Announcement"
    $site = Get-SPSite $siteUrl
	try
    {                
        $web = $site.OpenWeb($webUrl)
		try
        {
            $list = $web.Lists[$listName]			
			$listItems = $list.Items
			$itemCount = ($listItems.Count - 1)
			for($i=0; $i -lt $itemCount; $i++)
			{
				if(!($item.FileSystemObjectType -eq [Microsoft.SharePoint.SPFileSystemObjectType]::Folder))
				{
					$listItems.Delete($i)
				}				
			}		
			#Private Team Item
            $item = $list.Items.Add()
            $item["Title"] = ($webName + " " + $title + " -  1")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team Item
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  2")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue			
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Intranet Item
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  3")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Public Team
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  4")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team, Public Team, and Intranet Item
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  5")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team and Itranet Item
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  6")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Intranet Iteam
			$folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  7")
            $item["Body"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			Write-Host "Finished Adding Sample Announcements to "$siteUrl$webUrl" ("$listName")"
        }
		finally
		{
		    $web.Dispose()
		}
    }
    finally
    {
		$site.Dispose()
    }
}

function AddSampleLinks($siteUrl, $webUrl, $webName, $listName)
{
    $title = "Link"
    $site = Get-SPSite $siteUrl
	try
    {                
        $web = $site.OpenWeb($webUrl)
		try
        {
			#Private Team Item
            $list = $web.Lists[$listName]
            $item = $list.Items.Add()
            $item["Title"] = ($webName + " " + $title + " -  1")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 1"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  2")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 2"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  3")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 3"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Public Team
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  4")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 4"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team, Public Team, and Intranet Team
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  5")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 5"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team and Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  6")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 6"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  7")
            $urlValue = New-Object Microsoft.SharePoint.SPFieldUrlValue
            $urlValue.Description = $webName + " - " + $title + " 7"
            $urlValue.Url = "http://www.google.com"
            $item["URL"] = $urlValue
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			Write-Host "Finished Adding Sample Links to "$siteUrl$webUrl" ("$listName")"
        }
		finally
		{
		    $web.Dispose()
		}
    }
    finally
    {
		$site.Dispose()
    }
}

function AddSampleCalendarEvents($siteUrl, $webUrl, $webName, $listName)
{
    $title = "Event"
    $site = Get-SPSite $siteUrl
	try
    {                
        $web = $site.OpenWeb($webUrl)
		try
        {
			#Private Team Site Item
            $list = $web.Lists[$listName]
            $item = $list.Items.Add()
            $item["Title"] = ($webName + " " + $title + " -  1")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team Site Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  2")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  3")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Public Team Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  4")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team, Public Team, and Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  5")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Public Team and Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  6")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Public Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			#Private Team and Intranet Item
            $folder = $list.RootFolder.SubFolders["public"]			
            $item = $list.Items.Add($folder.ServerRelativeUrl, [Microsoft.SharePoint.SPFileSystemObjectType]::File)
            $item["Title"] = ($webName + " " + $title + " -  7")
            $item["Description"] = "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
            $siteVisValue = New-Object Microsoft.SharePoint.SPFieldMultiChoiceValue
            $siteVisValue.Add("Private Team")
            $siteVisValue.Add("Intranet")
            $item["Site Visibility"] = $siteVisValue
            $item.Update()
			Write-Host "Finished Adding Sample Events to "$siteUrl$webUrl" ("$listName")"
        }
		finally
		{
		    $web.Dispose()
		}
	}
	finally
	{
		$site.Dispose()
	}
}

function CreateSamplePublishingPortal($createWebApplication, $createSiteCollection, $env)
{
	#--------------Web App Variables-----------------
	$webApplicationName = "Intranet"	
	$appPoolUserName = "CORP\Administrator"										##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$appPoolPassword = ConvertTo-securestring "password" -asplaintext -force		##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$portNumber = "80"																##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$serverName = "SPSERVER"													##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$timeZoneId = 13 #Pacific Time (US and Canada)									##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	#--------------Site Collection Variables-----------------
	$siteName = "Intranet"
	$siteManagedPath = "/sites/Intranet" #"" if root level. Otherwise, something like "/sites/PortalName"
	$siteUrl = "http://" + $serverName + ":" + $portNumber + $siteManagedPath
	$siteOwner = "CORP\Administrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$siteTemplate = Get-SPWebTemplate "BLANKINTERNETCONTAINER#0" #BLANKINTERNETCONTAINER#0 - Publishing Portal STS#0 Team Site
	$siteColumnName = "Site Visibility"
	$siteColumnDefaultValue = "Private Team"
	$siteColumnGroup = "CompanyX Columns"
	#--------------Web Variables-----------------
	$webOwner = "CORP\Administrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$webTemplate = Get-SPWebTemplate "BLANKINTERNETCONTAINER#0"
	$disableCheckoutModeration = $true
	$removeLibraryApprovalWorkflow = $true
	$addTeamCollaborationFeature = $true
	$webTitles = @(
		"Departments",
		"Private",
		"Finance",
		"Human Resources",
		"Information Systems",
		"Marketing"
		"Public",
		"Finance",
		"Human Resources",
		"Information Systems",
		"Marketing"
		)		
	$webUrls = @(
		("/dep"),
		("/dep/private"),
		("/dep/private/fi"),
		("/dep/private/hr"),
		("/dep/private/is"),
		("/dep/private/mkt"),
		("/dep/public"),
		("/dep/public/fi"),
		("/dep/public/hr"),
		("/dep/public/is"),
		("/dep/public/mkt")
		)			
	$teamUrls = @(
		($siteManagedPath + "/dep/private/fi"),
		($siteManagedPath + "/dep/private/hr"),
		($siteManagedPath + "/dep/private/is"),
		($siteManagedPath + "/dep/private/mkt"),
		($siteManagedPath + "/dep/public/fi"),
		($siteManagedPath + "/dep/public/hr"),
		($siteManagedPath + "/dep/public/is"),
		($siteManagedPath + "/dep/public/mkt")
		)		
	$privateTeamUrls = @(
		($siteManagedPath + "/dep/private/fi"),
		($siteManagedPath + "/dep/private/hr"),
		($siteManagedPath + "/dep/private/is"),
		($siteManagedPath + "/dep/private/mkt")
		)	
	$privateTeamRelativeUrls = @(
		("~sitecollection/dep/private/fi"),
		("~sitecollection/dep/private/hr"),
		("~sitecollection/dep/private/is"),
		("~sitecollection/dep/private/mkt")
		)			
	$privateTeamNames = @(
		"Finance",
		"HR",
		"IS",
		"Marketing"
		)			
	$publicTeamUrls = @(
		($siteManagedPath + "/dep/public/fi"),
		($siteManagedPath + "/dep/public/hr"),
		($siteManagedPath + "/dep/public/is"),
		($siteManagedPath + "/dep/public/mkt")
		)		
	$siteGroups = @(
		"Finance Owners",
		"Finance Members",
		"Finance Visitors",
		"HR Owners",
		"HR Members",
		"HR Visitors",
		"IS Owners",
		"IS Members",
		"IS Visitors",
		"Marketing Owners",
		"Marketing Members",
		"Marketing Visitors"
	)	
	$siteGroupOwners = @(
		($siteName + " Owners"),
		"Finance Owners",
		"Finance Owners",
		($siteName + " Owners"),
		"HR Owners",
		"HR Owners",
		($siteName + " Owners"),
		"IS Owners",
		"IS Owners",
		($siteName + " Owners"),
		"Marketing Owners",
		"Marketing Owners"
	)		
	#NOTE: THIS ASSUMES YOU HAVE THESE USERS - MAKE ARRAY EMPTY IF NOT				##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
	$siteGroupDefaultUsers = @(
		"",
		"",
		"",
		"",
		"",
		"",	
		"",
		"",
		"",
		"",
		"",
		""		
#		"FIOwner",
#		"FIMember",
#		"FIVisitor",
#		"HROwner",
#		"HRMember",
#		"HRVisitor",
#		"ISOwner",
#		"ISMember",
#		"ISVisitor",
#		"MTKOwner",
#		"MTKMember",
#		"MTKVisitor"
	)	
	#--------------MasterPage Variables-----------------
	$masterPageUrl = $siteManagedPath + "/" + "_catalogs/masterpage/v4.master" #nightandday.master is default. v4.master is more minimalist
	#--------------List Variables-----------------
	$linksTemplate = [Microsoft.SharePoint.SPListTemplateType]::Links
	$announcementsTemplate = [Microsoft.SharePoint.SPListTemplateType]::Announcements
	$calendarTemplate = [Microsoft.SharePoint.SPListTemplateType]::Events
	$listNameTemplates = @($announcementsTemplate, $linksTemplate, $announcementsTemplate, $calendarTemplate)
	$listNames = @("Announcements", "I Want To", "News", "Team Calendar")
	$pageUrl = "/pages/default.aspx"	
	#--------------List View Variables-----------------
	$fieldNames = @("Name", "Site Visibility")
	$privateCamlQuery = "<Where><Contains><FieldRef Name='Site_x0020_Visibility' /><Value Type='Text'>Private Team</Value></Contains></Where><OrderBy><FieldRef Ascending='False' Name='Modified' /></OrderBy>"
	$publicCamlQuery = "<Where><Contains><FieldRef Name='Site_x0020_Visibility' /><Value Type='Text'>Public Team</Value></Contains></Where><OrderBy><FieldRef Ascending='False' Name='Modified' /></OrderBy>"
	$intranetCamlQuery = "<Where><Contains><FieldRef Name='Site_x0020_Visibility' /><Value Type='Text'>Intranet</Value></Contains></Where><OrderBy><FieldRef Ascending='False' Name='Modified' /></OrderBy>"
	$listSiteVisibilityTitle = ""
	$listSiteVisibilityChoices = @("Private Team", "Public Team", "Intranet")
	$listViewColumnFilterName = "Site_x0020_Visibility"
	$listViewColumnPublicFilterValue = "Public Team"
	$listViewColumnIntranetFilterValue = "Intranet"
	$listViewItemLimit = 10;
	$listViewZoneId = "TopZone"
	#--------------List Folder Variables-----------------	
	$listFolderName = "public"
	$listFolderPermissionGroup = ($siteName + " Visitors")
	$listFolderPermission = "Read"	
	#--------------Publishing Page Variables-----------------
	$publishingPages = @("NewHires.aspx", "StaffRoles.aspx", "Training.aspx")
	#--------------Permissions Variables-----------------
	$permissionPermissionNames = @(
		"Finance", 
		"HR", 
		"IS",
		"Marketing"	
	)		
	
	#--------------UPDATE VARIABLES DEPENDING ON ENVIRONMENT-----------------
	#You can add more variables from above down here. I only included common ones that would likely change between environments.
	#Expected Values: dev, qa, or prod	
	switch($env)
	{
		"dev" 
		{ 
			#--------------Web App Variables-----------------
			$webApplicationName = "DEVIntranet"	
			$appPoolUserName = "CORP\DEVAdministrator"										##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$appPoolPassword = ConvertTo-securestring "password" -asplaintext -force		##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$portNumber = "80"																##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$serverName = "DEVSPSERVER"														##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Site Collection Variables-----------------
			$siteName = "DEVIntranet"
			$siteManagedPath = "/sites/Intranet" #"" if root level. Otherwise, something like "/sites/PortalName"
			$siteUrl = "http://" + $serverName + ":" + $portNumber + $siteManagedPath
			$siteOwner = "CORP\DEVAdministrator"											##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Web Variables-----------------
			$webOwner = "CORP\DEVAdministrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
		}
		"qa" 
		{ 
			#--------------Web App Variables-----------------
			$webApplicationName = "QAIntranet"	
			$appPoolUserName = "CORP\QAAdministrator"										##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$appPoolPassword = ConvertTo-securestring "password" -asplaintext -force		##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$portNumber = "80"																##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$serverName = "QASPSERVER"														##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Site Collection Variables-----------------
			$siteName = "QAIntranet"
			$siteManagedPath = "/sites/Intranet" #"" if root level. Otherwise, something like "/sites/PortalName"
			$siteUrl = "http://" + $serverName + ":" + $portNumber + $siteManagedPath
			$siteOwner = "CORP\QAAdministrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Web Variables-----------------
			$webOwner = "CORP\QAAdministrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
		}
		"prod" 
		{ 
			#--------------Web App Variables-----------------
			$webApplicationName = "Intranet"	
			$appPoolUserName = "CORP\Administrator"											##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$appPoolPassword = ConvertTo-securestring "password" -asplaintext -force		##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$portNumber = "80"																##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			$serverName = "SPSERVER"														##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Site Collection Variables-----------------
			$siteName = "Intranet"
			$siteManagedPath = "/sites/Intranet" #"" if root level. Otherwise, something like "/sites/PortalName"
			$siteUrl = "http://" + $serverName + ":" + $portNumber + $siteManagedPath
			$siteOwner = "CORP\Administrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
			#--------------Web Variables-----------------
			$webOwner = "CORP\Administrator"												##########GLOBAL VARIABLE (UPDATE IF NECESSARY)
		}
	}	
	
	
	#--------------CREATE WEB APP AND SITE COLLECTION-----------------
	if($createWebApplication)
	{
		CreateWebApplication $webApplicationName $appPoolUserName $appPoolPassword $portNumber $serverName $timeZoneId
	}
	if($createSiteCollection)
	{
		CreateSiteCollection $siteName $siteUrl $siteOwner $siteTemplate $removeLibraryApprovalWorkflow $disableCheckoutModeration $addTeamCollaborationFeature
	}
	UpdateMasterPageUrl $siteUrl "" $masterPageUrl $false
	#--------------ADD SITE VISIBILITY SITE COLUMN-----------------	
	CreateSiteColumnMultiChoice $siteUrl $siteColumnName $listSiteVisibilityChoices $siteColumnDefaultValue $siteColumnGroup $true	
	#--------------CREATE SUB SITES-----------------	
	for($i=0; $i -lt $webTitles.Length; $i++)
	{
		$webUrl = ($siteUrl + $webUrls[$i])
		CreateWeb $siteUrl $webUrls[$i] $siteManagedPath $webTitles[$i] $webOwner $webTemplate $removeLibraryApprovalWorkflow $addTeamCollaborationFeature
		UpdateMasterPageUrl $siteUrl ($siteManagedPath + $webUrls[$i]) $masterPageUrl $false	
	}		
	#--------------ADD SITE GROUPS-----------------
	for($i=0; $i -lt $siteGroups.Length; $i++)
	{	
		AddSiteGroup $siteUrl $siteGroups[$i] $siteGroupDefaultUsers[$i] $siteGroupOwners[$i] ""
	}
	#--------------ADD PRIVATE WEB PAGES AND LISTS / SET PERMISSIONS-----------------
	for($i=0; $i -lt $privateTeamUrls.Length; $i++)
	{	
		$webUrl = ($siteUrl + $privateTeamUrls[$i])
		for($j=0; $j -lt $publishingPages.Length; $j++)
		{
			CreatePublishingPage $siteUrl $privateTeamUrls[$i] $publishingPages[$j] $publishingPages[$j].Replace(".aspx", "")
		}
		for($j=0; $j -lt $listNames.Length; $j++)
		{
			CreateList $siteUrl $privateTeamUrls[$i] $listNames[$j] "" $listNameTemplates[$j]
			AddListSiteColumn $siteUrl $privateTeamUrls[$i] $listNames[$j] "Site Visibility"
		}		
		SetRoleInheritance $siteUrl $privateTeamUrls[$i] $true	
	}
	#--------------SET PRIVATE WEB GROUP PERMISSIONS-----------------	
	for($i=0; $i -lt $privateTeamUrls.Length; $i++)
	{
		RemoveGroupPermission $siteUrl $privateTeamUrls[$i] ($siteName + " Visitors")
		AddGroupPermission $siteUrl $privateTeamUrls[$i] ($permissionPermissionNames[$i] + " Visitors") "Read"
		AddGroupPermission $siteUrl $privateTeamUrls[$i] ($permissionPermissionNames[$i] + " Members") "Contribute"
		AddGroupPermission $siteUrl $privateTeamUrls[$i] ($permissionPermissionNames[$i] + " Owners") "Full Control"		
	}		
	#--------------CREATE LIST FOLDERS, PERMISSIONS, AND VIEWS-----------------	
	for($i=0; $i -lt $privateTeamUrls.Length; $i++)
	{		
		for($l=0; $l -lt $listNames.Length; $l++)
		{	
			AddListFolder $siteUrl $privateTeamUrls[$i] $listNames[$l] $listFolderName $true			
			SetListFolderPermissions $siteUrl $privateTeamUrls[$i] $listNames[$l] $listFolderName $listFolderPermissionGroup $listFolderPermission				
			for($m=0; $m -lt $listSiteVisibilityChoices.Length; $m++)
			{
				AddListView $siteUrl $privateTeamUrls[$i] $listNames[$l] $listSiteVisibilityChoices[$m] $fieldNames $privateCamlQuery 10 $false $false $false
			}		
			#ADD Content Query Web Part to Public Page
			AddContentByQueryWebPart $siteUrl $publicTeamUrls[$i] $privateTeamRelativeUrls[$i] $privateTeamUrls[$i] ($publicTeamUrls[$i] + $pageUrl) $listNames[$l] $listNames[$l] $listViewColumnFilterName $listViewColumnPublicFilterValue $listViewColumnPublicFilterValue $listViewItemLimit $listViewZoneId 0			
			#ADD Content Query Web Part to Intranet Home Page #TODO: FIGURE OUT WHY THIS HAS TO BE RUN SEPARATELY
			#AddContentByQueryWebPart $siteUrl "" $privateTeamRelativeUrls[$i] $privateTeamUrls[$i] ($siteUrl + $pageUrl) $listNames[$l] ($privateTeamNames[$i]+" - "+$listNames[$l]) $listViewColumnFilterName $listViewColumnIntranetFilterValue $listViewColumnIntranetFilterValue $listViewItemLimit $listViewZoneId 0						
		}		
	}	
	#--------------ADDING SAMPLE DATA TO LISTS-----------------
	for($i=0; $i -lt $privateTeamUrls.Length; $i++)
	{
		AddSampleAnnouncements $siteUrl $privateTeamUrls[$i] $privateTeamNames[$i] "Announcements"
		AddSampleAnnouncements $siteUrl $privateTeamUrls[$i] $privateTeamNames[$i] "News"
		AddSampleCalendarEvents $siteUrl $privateTeamUrls[$i] $privateTeamNames[$i] "Team Calendar"
		AddSampleLinks $siteUrl $privateTeamUrls[$i] $privateTeamNames[$i] "I Want To"
	}
	Write-Host "--------------FINISHED CREATING PUBLISHING PORTAL-----------------"
}
#--------------START HERE---------------------------------------------------------------------------------------------------
Clear-Host
$env = "dev" #"dev", "qa", or "prod" Make sure to update variables within the function.
$createWebApplication = $false
$createSiteCollection = $true
CreateSamplePublishingPortal $createWebApplication $createSiteCollection $env
[System.Console]::Read()