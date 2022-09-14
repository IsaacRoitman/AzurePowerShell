# Script to update ADF Linked Services to a new Integrated Runtime
# Uses a combination of PowerShell for scripting and AZ CLI for the update commands
# Isaac H. Roitman, 9/2022

# ADF information and filepath variables to update, ensure the new Linked Service is created first
$localFilePath = "C:\Users\isroitma\OneDrive\IT\PowerShell\SCRIPTS\Azure\ADF"
$ResourceGroupName = "testrg"
$DataFactoryName = "ircsadf"
$OldIntegrationRuntimeName = "IntegrationRuntime1"
$NewIntegrationRuntimeName = "newIntegrationRuntime"

$connectViaNew = @"
{'referenceName': '$newIntegrationRuntimeName'}
"@

# Get all Linked Services from the existing ADF
$linkedServices = az datafactory linked-service list --resource-group "$ResourceGroupName" --factory-name "$DataFactoryName"

# Convert JSON to an array of PS objects
$linkedServices = $linkedServices | ConvertFrom-Json -Depth 20

# Filter array to include only Linked Services linked to the existing IR
$irLinkedServices = $linkedServices | Where-Object {$_.properties.connectvia.referencename -eq $OldIntegrationRuntimeName}

# Create a backup file of the Linked Services
$irLinkedservices | Out-File ($localFilePath + "IR_backup.json")

# Iterate through the array and update the Linked Service to the new IR
foreach ($linkedService in $irLinkedServices)
{
    # Update the Linked Service to the new IR
    $output = az datafactory linked-service update --resource-group "$ResourceGroupName" --factory-name "$DataFactoryName" --linked-service-name $linkedService.name --connect-via $connectViaNew --only-show-errors

    if (!$output) {
        Write-Error "Error updating ADF Linked Service: $($linkedService.Name)"
    }
    else {
        Write-Host "Updated new ADF Linked Service: $($linkedService.Name)"
        return $output
    }
}

# Validate changes in post update report (can be modified to show all Linked Services or just ones with an IR)
$linkedServices = az datafactory linked-service list --resource-group "$ResourceGroupName" --factory-name "$DataFactoryName" | ConvertFrom-Json -Depth 20

$report = $linkedServices | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        ResourceGroup = $_.ResourceGroup
        Type = $_.Properties.Type
        IntegratedRuntime = $_.Properties.connectvia.referencename
    }
}

$report | Export-Csv ($localFilePath + "\LinkedServicesReport.csv") -NoTypeInformation
Invoke-Item ($localFilePath + "\LinkedServicesReport.csv")
