
<#
.SYNOPSIS
Sets Maintenance Mode for a Windows Server
Version 1.00

.DESCRIPTION
This sets Maintenance Mode for a single server

.PARAMETER  thisVar

.PARAMETER  thatVar

.EXAMPLE
ABC -thisvar "Hello" -thatvar 10

#>

function Start-SCOMMaintenanceforGroup {
[CmdletBinding(SupportsShouldProcess=$true)]
      param
      (
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
          HelpMessage='What is the ComputerGroup you want to put in Maintenance Mode?')]
        [Alias("Group")]
        [string[]]$ComputerGroup,
        [Parameter(Mandatory=$True,
        ValueFromPipeline=$false,
        ValueFromPipelineByPropertyName=$True,
          HelpMessage='Specifies the time the maintenance will end. The minimum amount of time a resource can be in 
        maintenance mode is 5 minutes. This is a required parameter')]
        [int]$EndTime,
        [Parameter(Mandatory=$False,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
          HelpMessage='UnplannedOther, PlannedHardwareMaintenance, UnplannedHardwareMaintenance, 
        PlannedHardwareInstallation, UnplannedHardwareInstallation, PlannedOperatingSystemReconfiguration, 
        UnplannedOperatingSystemReconfiguration, PlannedApplicationMaintenance, ApplicationInstallation, 
        ApplicationUnresponsive, ApplicationUnstable, SecurityIssue, LossOfNetworkConnectivity')]
        [string]$Reason,
        [Parameter(Mandatory=$False,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
          HelpMessage='Allows you to type a comment about the maintenance activity.')]
        [string]$Comment,
        [switch]$EventLog
      )

	Begin
    {
        Write-Verbose "Starting Function Start-SCOMMaintenanceModeForGroup Function"
        #Check for minumum Maintenance mode period of 5 mins.
        if($endtime -lt 5)
        {
            Write-Error "The time span for the maintenance mode should be at least 5 minutes." -ErrorAction Stop
        }
        Write-Verbose "Following Group Members will be put in Maintenance Mode:"
        $ComputerGroupMembers = Get-SCOMMonitoringObject -DisplayName $ComputerGroup        
        if($ComputerGroupMembers)
        {
            $ComputerGroupMemberNames = ($ComputerGroupMembers.getrelatedMonitoringObjects() | select DisplayName)
            Write-Verbose "$ComputerGroupMemberNames"
            #Retrieve Management Servers so we can check if we don't put Management Servers in MM.
            $MSs = Get-SCOMManagementServer
        }
        else
        {
            Write-Error "No Members of ComputerGroup $ComputerGroup found" -ErrorAction Stop
        }
    } #End Begin

    Process
    {
        #Put Agents in Maintenance Mode
        foreach ($agent in $ComputerGroupMembers.getrelatedMonitoringObjects())
        {
            Write-Verbose "Checking if ComputerGroup Member $agent is not a Management Server"
            #if(($MSs | Select DisplayName).displayname -eq $agent)
                 if(($MSs | Select DisplayName) -eq $agent)
            {
                Write-Verbose "We don't want to put a Management Server in MM. Skipping"
            }
            else
            {
                Write-Verbose "Let's put Agent $Agent in Maintenance Mode"
                $Instance = Get-SCOMClassInstance -Name $Agent
                if ($PSCmdlet.ShouldProcess("Putting $Agent in Maintenande Mode for $($Endtime) minutes") ) 
                {
                    #Added 5 seconds to EndTime to prevent failing the Start-SCOMMaintenanceMode cmdlet. Min. 5 mins is needed.
                    Start-SCOMMaintenanceMode -Instance $Instance -EndTime ([System.DateTime]::Now).AddSeconds(5).addMinutes($EndTime) -Reason $Reason -Comment $Comment
                }#End of whatif
            }#End of else
        }#End Foreach
        if ($PSBoundParameters['EventLog'])
        {        
            write-eventlog -LogName "Operations Manager" -Source "OpsMgr SDK Service" -EventID 999 -message "The following Objects are put into in Maintenance Mode for $($EndTime) minutes: $($ComputerGroupMembers.getrelatedMonitoringObjects())"
        }#End if
        
    } #End Process

    End
    {
        Write-Verbose "Finished Function Start-SCOMMaintenanceModeForGroup Function"
    }

}