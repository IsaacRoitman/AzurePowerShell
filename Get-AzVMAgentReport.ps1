<#
.Synopsis
   Cmdlet to gather Azure Log Analytics extension info from Azure VMs
.DESCRIPTION
    Gathers Azure Log Analytics extension info from Azure VMs as well as provide the Log Analytics 
    workspace(s) which the VM is connected to.  The goal of this cmdlet is to provide a simple way to report 
    on current monitoring agent status and configuration.
.EXAMPLE
   PS C:\> Get-AzVMAgentReport
   This will report on all VMs within the currently connected subscription
.EXAMPLE
   PS C:\>Get-AzVMAgentReport -VMName *vm1
   Using the VMName parameter will report on a specific VM or wildcard match of VMs within the currently connected subscription (not required, * is default)
.EXAMPLE
   PS C:\>Get-AzVMAgentReport -SubscriptionName prod-subs-1 -VMName *
   Using the SubscriptionName parameter will connect to a specific Azure Subscription and report on all VMs (or specific VMs if VMName is utilized)
.INPUTS
   Paramaters for VM name
   Paramater for Subscription name
.OUTPUTS
  VMName            : mywindowsvm1     
  ResourceGroupName : OPERATIONS
  OsType            : Windows
  Location          : eastus 
  ExtensionType     : MicrosoftMonitoringAgent
  Publisher         : Microsoft.EnterpriseCloud.Monitoring
  WorkspaceName     : myomsworkspace1
  WorkspaceId       : 02195123-9999-4672-9987-d9f4bfaeb000
  DaysRetention     : 30
  AllAgents         : AzureNetworkWatcherExtension, AzurePolicyforWindows, BGInfo, DependencyAgentWindows, enablevmaccess, Microsoft.EnterpriseCloud.Monitoring
.NOTES
   Isaac H. Roitman, July 2020 v1.1
.FUNCTIONALITY
   The ability to easily report on Azure VM agent status
#>
function Get-AzVMAgentReport
{
    [CmdletBinding()]
    param (
        $VMName = "*",
        $SubscriptionName
    )
    
    if ($SubscriptionName)
    {
        Set-AzContext -Name $SubscriptionName
    }

    $azcontext = Get-AzContext

    Write-Host "Connected to subscription $($azcontext.Name)" -ForegroundColor Cyan

    $workspaces = Get-AzOperationalInsightsWorkspace
    
    $vms = Get-AzVM -VMName $VMName

    Write-Host "$($vms.count) VMs found in subscription $($azcontext.Subscription.Name)" -ForegroundColor Cyan

    $n = $null

    foreach ($vm in $vms)
    {
        $n++
        Write-Host "Working on $n of $($vms.count)" -ForegroundColor Cyan

        if ($null -eq $vm.OSProfile.WindowsConfiguration) {
            $ostype = "Linux"
            $agents = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction SilentlyContinue
            $agent = $agents | Where-Object Name -Match OMS 
        
        }
        else {
            $ostype = "Windows"
            $agents = Get-AzVMExtension -ResourceGroupName $vm.ResourceGroupName -VMName $vm.Name -ErrorAction SilentlyContinue
            $agent = $agents | Where-Object Name -Match Microsoft.EnterpriseCloud.Monitoring 
        }

        $vmworkspace = $workspaces | Where-Object {$_.CustomerId -eq ($agent.PublicSettings | ConvertFrom-Json).WorkspaceId} -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            VMName = $vm.Name
            Subscription = $azcontext.Subscription.Name
            ResourceGroupName = $vm.ResourceGroupName
            OsType = $ostype
            Location = $agent.Location
            AgentName = $agent.Name
            AgentPublisher = $agent.Publisher
            AgentExtensionType = $agent.ExtensionType
            WorkspaceName = $vmworkspace.Name
            WorkspaceId = $vmworkspace.CustomerId
            DaysRetention = $vmworkspace.retentionInDays
            AllAgents = $agents.Name -join ', '
        }
    }
}
