

function New-MsAuthToken {
    $postParams = @{
        resource = "$resource"
        client_id = "$clientId"
        client_secret = "$clientsecret"
        grant_type = "client_credentials"
    }

    $Global:token = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenant/oauth2/token" -Body $postParams
    
    Write-Warning "New token retrieved at $(Get-Date)"
    
    $token
    
    $Global:headers = @{
        Authorization = "$($token.token_type) $($token.access_token)"
        consistencylevel = "eventual"
    }
}

function Get-MgData ($Uri) {

    $start = Get-Date
    
    New-MsAuthToken | Out-Null
    
    $result = Invoke-RestMethod -Uri $Uri -Headers $headers
    $resultValue = $result.Value
    
    if ($resultValue) {
        Write-Host "Retrieved $($resultValue.Count) records"
    }

    while ($null -ne $result.'@odata.nextLink') {
        try { 
            $result = Invoke-RestMethod -Uri $result.'@odata.nextLink' -Headers $headers -ErrorAction Stop
            $resultValue += $result.value
        }
        catch {           
            # Get a new auth token and update header with the new token
            $token = New-MsAuthToken        
            $headers.Authorization = "$($token.token_type) $($token.access_token)"
        
            $result = Invoke-RestMethod -Uri $result.'@odata.nextLink' -Headers $headers
            $resultValue += $result.value
        }

        if ($resultValue) {
            Write-Host "Retrieved $($resultValue.Count) records"
        }
    }

    $end = Get-Date
    
    if ($resultValue) {
        $resultValue
        Write-Host "Retrieved $($resultValue.Count) total records in $([math]::Round((New-TimeSpan $start $end).TotalMinutes,2)) minutes" -ForegroundColor Yellow
    }
    else {
        $result
    }
}

# Define 30 day time window and create the date string for queries
$30daysago = (Get-Date).AddDays(-30)

# Filter for users created in last 30 days
$usersCreatedIn30days = ($users | Where-Object {$_.createdDateTime -ge $30daysago}).Count
    
# Create the output object
$body = @{
    'usersCreatedIn30days' = ($users | Where-Object {$_.createdDateTime -ge $30daysago}).Count
    
    'localUsers' = ($users | Where-Object {$_.userType -eq "member"}).Count  
    'localUsersCreatedIn30days' = ($usersCreatedIn30days | Where-Object {$_.userType -eq "member"}).Count

    'federatedUsers' = ($users | Where-Object {$_.userType -eq "guest"}).Count  
    'federatedUsersCreatedIn30days' = ($usersCreatedIn30days | Where-Object {$_.userType -eq "guest"}).Count

    'activeUsers' = ($users | Where-Object {$_.accountEnabled -eq $true}).Count
    'activeUsersCreatedIn30days' = ($usersCreatedIn30days | Where-Object {$_.accountEnabled -eq $true}).Count

    'inactiveUsers' = ($users | Where-Object {$_.accountEnabled -eq $false}).Count
    'inactiveUsersCreatedIn30days' = ($usersCreatedIn30days | Where-Object {$_.accountEnabled -eq $false}).Count

    'allApplications' = $allApplications.Count
    'b2cApps' = ($allapplications | Where-Object {$_.SignInAudience -eq "AzureADandPersonalMicrosoftAccount"}).Count
    'apiApps' = ($allApplications | Where-Object {$_.api.oauth2permissionscopes}).Count
    
    'mfaSignIns' = ($SigninLogs | Where-Object {$_.authenticationDetails.authenticationStepResultDetail -match "MFA"}).mfaDetail | group-object authMethod
}
