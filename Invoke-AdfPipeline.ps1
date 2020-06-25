<#
.Synopsis
   Text based application to run specific ADF pipelines
.DESCRIPTION
   Text based application written in PowerShell for running ADF (Azure Data Factory pipelines).  The goal of this application is to remove complexity
   and provide business users with a simple interface to invoke specific ADF pipelines.
.EXAMPLE
   .\Invoke-AdfPipelines
   Please select a Data Factory Pipeline number to invoke:
   1 - Pipeline1
   2 - Blob to alternate region backup
   3 - Cosmos to ADLS
   4 - Exit
   Select an option (1-4): 1
.INPUTS
   Variables for Subscription, ResourceGroupName, and DataFactoryName must be entered in the script
   Variables for ADF pipeline names must be entered in the script
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
Clear-Host
$date = Get-Date
Import-Module Az.Accounts,Az.DataFactory

# Set variables for Azure subscription and ADF
$Subscription = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
$ResourceGroupName = "resourcegroupname"
$DataFactoryName = "datafactoryname"

# Check that Azure context is correct and initate login if needed
$context = Get-AzContext
if ($context.Subscription.Id -eq $Subscription)
{
    Write-Host "`r`nSuccessfully connected to $($context.Subscription.Name) as $($context.Account.Id)`r`n" -ForegroundColor Green
}
elseif ($context.Subscription.Id -ne $Subscription)
{ 
    Login-AzAccount -Subscription $Subscription -Verbose
    $context = Set-AzContext -Subscription $Subscription
    Write-Host "`r`nSuccessfully connected to $($context.Subscription.Name) as $($context.Account.Id)`r`n" -ForegroundColor Green
}
else
{
    Write-Warning "Error connecting to subscription $subscription"
    exit
}

# Main program to select and initiate pipeline run
do
{
    Write-Host $date.ToString() -ForegroundColor Cyan
    Write-Host "Please select a Data Factory Pipeline number to invoke:`r`n" -ForegroundColor Cyan 

    # Set variables for ADF pipeline names
    $1 = "Pipeline1"
    $2 = "Blob to alternate region backup"
    $3 = "Cosmos to ADLS"

    # Display the options on screen as a menu
    Write-Host "1 - $1" -ForegroundColor Yellow
    Write-Host "2 - $2" -ForegroundColor Yellow
    Write-Host "3 - $3" -ForegroundColor Yellow
    Write-Host "4 - Exit" -ForegroundColor Yellow

    # Collect the selection number
    Write-Host "`r`nSelect an option (1-4): " -ForegroundColor Yellow -NoNewLine
    $x = Read-Host

    # Invoke the pipeline run based on the selection number
     $job = switch ($x)
    {
        '1' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $1 -Verbose}
        '2' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $2 -Verbose}
        '3' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $3 -Verbose}
        Default {exit}
    }
    Write-Host "`r`nStarting pipeline $((Get-Variable -Name $x).Value), please wait. . ." -ForegroundColor Yellow
    "Job ID $job"

    # Get detailed job results and display to screen, refresh status every 1 second
    do
    {
        $rundetails = Get-AzDataFactoryV2ActivityRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $job -RunStartedAfter $date -RunStartedBefore (Get-Date)
        $rundetails.Status
        Start-Sleep 1
    } until ($rundetails.Status -match "Succeeded|Fail")

    switch ($rundetails.Status){
        'Succeeded' {'Green'}
        'Failed' {'Yellow'}
    }
    $rundetails
    Write-Host "`r`nADF pipeline job $($rundetails.PipelineName) completed with status $($rundetails.Status)`r`n" -ForegroundColor $color

    # Run again or exit
    $again = Read-Host "Run another pipeline? (Press 'y' to run again or any key to exit)"
}
while ($again -eq "y")
