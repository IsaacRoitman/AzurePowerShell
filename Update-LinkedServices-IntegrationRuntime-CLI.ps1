# ADF information and filepath variables, ensure the new Linked Service is created first
$localFilePath = "C:\Users\isroitma\OneDrive\IT\PowerShell\SCRIPTS\Azure\ADF"
$ResourceGroupName = "testrg"
$DataFactoryName = "ircsadf"
$oldIntegrationRuntimeName = "IntegrationRuntime1"
$newIntegrationRuntimeName = "newIntegrationRuntime"

$connectViaNew = @"
{'referenceName': '$newIntegrationRuntimeName'}
"@

# Get all Linked Services from the existing ADF
$linkedServices = az datafactory linked-service list --resource-group "$resourcegroupname" --factory-name "$DataFactoryName"

# Convert JSON to an array of PS objects
$linkedServices = $linkedservices | ConvertFrom-Json -Depth 20

# Filter array to include only Linked Services linked to the existing IR
$irLinkedServices = $linkedservices | Where-Object {$_.properties.connectvia.referencename -eq $oldIntegrationRuntimeName}

# Create a backup file of the Linked Services
$irLinkedservices | Out-File ($localFilePath + "IR_backup.json")

# Iterate through the array and update the Linked Service to the new IR
foreach ($linkedService in $irLinkedServices)
{
    # Update the Linked Service to the new IR
    $output = az datafactory linked-service update --resource-group "$resourcegroupname" --factory-name "$DataFactoryName" --linked-service-name $linkedService.name --connect-via $connectViaNew --only-show-errors

    if (!$output) {
        Write-Error "Error updating ADF Linked Service: $($linkedService.Name)"
    }
    else {
        Write-Host "Updated new ADF Linked Service: $($linkedService.Name)"
        return $output
    }
}

# Validate changes in post update report (can be modified to show all Linked Services or just ones with an IR)
$linkedServices = az datafactory linked-service list --resource-group "$resourcegroupname" --factory-name "$oldDataFactoryName" | ConvertFrom-Json -Depth 20

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