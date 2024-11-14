# Run a script in parallel on Arc Connected Machines
# Example imports a CSV blob from a storage account, loops through CSV, and executes on the Arc machine based on passed parameters
# Isaac H. Roitman, 2024

param (
    [string]$storageAccountResourceGroup = "rg-server-automation-app",
    [string]$storageAccountName = "storageserverautomation",
    [string]$storageContainerName = "csvinput",
    [string]$blobName = "server_folders.csv"
)

$startTime = Get-Date
$PSStyle.OutputRendering = "PlainText"
$errorActionPreference = "Stop"
$localFilePath = "C:\app"

$location = "centralus"
$resourceGroup = "rg-arc"
$subscriptionId1 = "Subs-ID-here"
$subscriptionId2 = "Subs-ID-here"

# Authenticate to Azure
Connect-AzAccount -Identity | Out-Null
Write-Host "Connected to Azure with managed identity`r`n"

# Create a storage context using Azure AD credentials
$context = New-AzStorageContext -StorageAccountName $storageAccountName -UseConnectedAccount

# Get the CSV from Blob Storage and download to the local machine
$blob = Get-AzStorageBlob -Container $storageContainerName -Blob $blobName -Context $context
$blob | Get-AzStorageBlobContent -Destination $localFilePath -Force
Write-Host "File $($blob.Name) downloaded to $localFilePath`r`n"

# Import the CSV file
$server_folders = Import-Csv -Path $localFilePath\$blobName
Write-Host "File $($blob.Name) imported to memory from $localFilePath, ready to execute the foreach loop`r`n"
$server_folders

# Define the script block to run on the remote computers
$scriptBlock = @"
param (
    [string]`$DirectoryPath,
    [string]`$UserName
)

# Output the current computername and IPv4 address
`$ipv4address = (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp).IPAddress
Write-Host "Successfully connected to: `$(`$env:COMPUTERNAME)" 
Write-Host "Local computername is: `$(`$env:COMPUTERNAME)"
Write-Host "Local IPv4 address is: `$ipv4address"

# Get the current ACL
`$acl = Get-Acl -Path `$DirectoryPath

# Filter the access rule for the specified user
`$accessRule = `$acl.Access | Where-Object {`$_.IdentityReference -like "*`$UserName"}

if (`$accessRule) {
    `$accessRule
    # Remove the access rule
    `$acl.RemoveAccessRule(`$accessRule)
    
    # Apply the updated ACL
    Set-Acl -Path `$DirectoryPath -AclObject `$acl
    Write-Host "Removed access rights for user `$UserName from directory `$DirectoryPath on `$(`$env:COMPUTERNAME)."
} 
else {
    Write-Host "No access rights found for user `$UserName on directory `$DirectoryPath on `$(`$env:COMPUTERNAME)."
}
"@

# Loop through the CSV file and perform the operation on each remote computer
#foreach ($item in $server_folders) {
$server_folders | ForEach-Object -Parallel {
    $item = $_
    $ComputerName = $item.ServerName
    $UserName = $item.User
    $DirectoryPath = $item.Folder
    
    $parameters = @(
        @{
            Name = 'DirectoryPath'
            Value = $directoryPath
        },
        @{
            Name = 'UserName'
            Value = $userName
        }
    )
        
    Write-Host "Running command on $ComputerName"
    
    New-AzConnectedMachineRunCommand -ResourceGroupName $using:resourceGroup -SubscriptionId $using:subscriptionId1 `
        -MachineName $ComputerName -Location $using:location `
        -RunCommandName "RemoveUserAccess" -SourceScript $using:scriptBlock `
        -Parameter $parameters
} -ThrottleLimit 10 

$endTime = Get-Date
$timespan = New-TimeSpan -Start $startTime -End $endTime
Write-Host "Completed!"
Write-Host "Total time to process $($server_folders.Count) items was $($timespan.Minutes) minutes and $($timespan.Seconds) seconds."