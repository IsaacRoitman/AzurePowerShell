function Get-AzWebAppConfig ($ResourceGroupname)
{
    $azContext = Get-AzContext
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
    $token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)

    $headers = @{
        'Content-Type'='application/json'
        'Authorization'='Bearer ' + $token.AccessToken
    }

    $apps = Get-AzWebApp -ResourceGroupName $ResourceGroupName | Where-Object Kind -EQ 'app'

    foreach ($app in $apps) {
        $uri = 'https://management.azure.com/' + $apps.Id + '/config/web?api-version=2019-08-01'

        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        
        $response.properties | Add-Member -MemberType NoteProperty -Name id -Value $response.id -Force
        $response.properties | Add-Member -MemberType NoteProperty -Name id -Value $response.name -Force
        $response.properties | Add-Member -MemberType NoteProperty -Name id -Value $response.type -Force
        $response.properties | Add-Member -MemberType NoteProperty -Name id -Value $response.location -Force
        $response.properties  
    }
}
