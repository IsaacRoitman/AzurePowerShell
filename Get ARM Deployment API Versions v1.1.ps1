# https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/child-resource-name-type
# https://about-azure.com/find-outdated-azure-arm-quickstart-templates-on-github/

# Get ARM Deployoments with API Versions
# Isaac H. Roitman, 4/2023

# Function to create the object output
function Output-ResourceDeployment {
    [PSCustomObject]@{
        SubscriptionName = $azContext.Subscription.Name
        SubscriptionId = $azContext.Subscription.Id    
        ResourceGroupName = $rg.ResourceGroupName
        ResourceGroupLocation = $rg.Location
        DeploymentName = $deployment.DeploymentName
        DeploymentId = $deployment.CorrelationId
        DeploymentTimeStamp = $deployment.Timestamp
        DeploymentTemplateLink = $deployment.TemplateLink
        ResourceType = $resource.type
        ResourceApiVersion = $resource.apiVersion
    }
}

# Define the local file path (can save all templates if needed or overwrite each time for reporting purposes)
$localPath = "$HOME\OneDrive - Microsoft\Documents\ARM Exports\"

# Get the current Azure Context
$azContext = Get-AzContext

# Get all ResourceGroups in the current Azure Context and loop through each
$resourceGroups = Get-AzResourceGroup

# Begin loop through all Resource Groups
$report = foreach ($rg in $resourceGroups) {

    # Get Deployments for the current Resource Group
    $rgDeployments = Get-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName | Where-Object ProvisioningState -NE "Failed"

    # Loop through the Resource Group Deployments
    foreach ($deployment in $rgDeployments) {
        # Create the filename and full path
        $fileName = $($deployment.DeploymentName + '_' + $deployment.Timestamp.GetDateTimeFormats("s") + '.json') -replace ':','-'
        $fullPath = Join-Path -Path $localPath -ChildPath $fileName
        
        # Get the deployment template and save the JSON file locally to the full path
        $template = Save-AzResourceGroupDeploymentTemplate -ResourceGroupName $deployment.ResourceGroupName -DeploymentName $deployment.DeploymentName `
            -Path $fullPath -Force
        
        # Load the JSON file into memory as a PS Object
        $object = Get-Content $template.Path | ConvertFrom-Json

        # Deployment templates can have up to 5 levels of nested resources, iterate through each level and get all, output PS object
        foreach ($resource in $object.resources) {
            Output-ResourceDeployment
        
            if ($resource.resources) {
                foreach ($resource in $resource.resources) {
                    Output-ResourceDeployment
        
                    if ($resource.resources) {
                        foreach ($resource in $resource.resources) {
                            Output-ResourceDeployment
                        
                            if ($resource.resources) {
                                foreach ($resource in $resource.resources) {
                                    Output-ResourceDeployment
        
                                    if ($resource.resources) {
                                        foreach ($resource in $resource.resources) {
                                            Output-ResourceDeployment
                                        
                                            if ($resource.resources) {
                                                foreach ($resource in $resource.resources) {
                                                    Output-ResourceDeployment
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }    
    }
}

# Export the report to CSV
$report | Export-Csv $($localPath + "ARM_Deployment_Report.csv") -NoTypeInformation

# Open the CSV file
Invoke-Item $($localPath + "ARM_Deployment_Report.csv") 