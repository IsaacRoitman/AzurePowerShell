Clear-Host
$date = Get-Date
Import-Module Az.Accounts,Az.DataFactory

# Set variables for Azure
$Subscription = 'b11918af-a87b-480e-ba88-369e9dadc5bf'
$ResourceGroupName = 'testrg'
$DataFactoryName = 'ircsadf'

# Set variables for ADF pipeline names
$1 = "Pipeline1"
$2 = "Blob to alternate region backup"
$3 = "Cosmos to ADLS"
[array]$pipelines = $1,$2,$3

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
    $n = $null
    Write-Host $date.ToString() -ForegroundColor Cyan
    Write-Host "Please select a Data Factory Pipeline number to invoke:`r`n" -ForegroundColor Cyan 

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