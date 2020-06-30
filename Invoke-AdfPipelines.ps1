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
   Variables for the specific ADF pipeline names must be entered in the script
   Switch statements to invoke the correct number of pipelines must be entered in the script (starts with Invoke-AzDataFactoryV2Pipeline)
.OUTPUTS
    ADF pipeline pipeline1 completed in 0 minutes and 51 seconds with status Succeeded
    Run another pipeline? (Press 'y' to run again or any key to exit):
.NOTES
   Isaac H. Roitman, June 2020
.FUNCTIONALITY
   The ability to easily run pipelines without loging into the portal or running specific PowerShell commands
#>
# Set variables for Azure subscription and ADF
$Subscription = 'XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'
$ResourceGroupName = "resourcegroupname"
$DataFactoryName = "datafactoryname"

# Set variables for ADF pipeline names
$1 = "Pipeline1"
$2 = "Blob to alternate region backup"
$3 = "Cosmos to ADLS"
[array]$pipelines = $1,$2,$3

Clear-Host
Import-Module Az.Accounts,Az.DataFactory

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
    $date = Get-Date
    $n = $null
    Write-Host $date.ToString() -ForegroundColor Cyan
    Write-Host "`r`nPlease select a Data Factory Pipeline number to invoke:`r`n" -ForegroundColor Cyan 

    # Display the options on screen as a menu
    foreach ($pipeline in $pipelines)
    {
        $n++
        Write-Host "$n - $pipeline" -ForegroundColor Yellow
    }
    $n++ 
    Write-Host "$n - Exit" -ForegroundColor Yellow

    # Collect the selection number
    Write-Host "`r`nSelect an option (1-4): " -ForegroundColor Yellow -NoNewLine
    $x = Read-Host

    # Invoke the pipeline run based on the selection number
    Write-Host "`r`nInvoking pipeline $((Get-Variable -Name $x).Value), please wait. . ." -ForegroundColor Yellow
    $job = switch ($x)
    {
        # Enter one line per pipeline and reference PipeLineName variable
        '1' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $1 -Verbose}
        '2' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $2 -Verbose}
        '3' {Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineName $3 -Verbose}
        Default {exit}
    }
    "Job ID $job"

    # Get detailed run results and display to screen
    do
    {
        $rundetails = Get-AzDataFactoryV2ActivityRun -ResourceGroupName $ResourceGroupName -DataFactoryName $DataFactoryName -PipelineRunId $job -RunStartedAfter $date -RunStartedBefore (Get-Date)
        $rundetails.Status
        Start-Sleep 1
    } until ($rundetails.Status -match "Succeeded|Fail")

    $color = switch ($rundetails.Status){
        'Succeeded' {'Green'}
        'Failed' {'Yellow'}
    }
    $rundetails
    $runtime = New-TimeSpan -Start $rundetails.ActivityRunStart -End $rundetails.ActivityRunEnd
    Write-Host "`r`nADF pipeline $($rundetails.PipelineName) completed in $($runtime.Minutes) minutes and $($runtime.Seconds) seconds with status $($rundetails.Status)`r`n" -ForegroundColor $color

    # Run again or exit
    $again = Read-Host "Run another pipeline? (Press 'y' to run again or any key to exit)"
}
while ($again -eq "y")
