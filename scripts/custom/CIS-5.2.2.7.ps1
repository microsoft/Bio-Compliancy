Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}

$policies = Get-MgBetaIdentityConditionalAccessPolicy

$state = 'enabled' #'enabledForReportingButNotEnforced'

$correctPolicyFound = $false
foreach ($policy in $policies)
{
    $results = @{}

    $results.containsAllUsers = $false
    if ($policy.Conditions.Users.IncludeUsers.Count -eq 1 -and $policy.Conditions.Users.IncludeUsers -contains "All")
    {
        $results.containsAllUsers = $true
    }

    $results.containsAllCloudApps = $false
    if ($policy.Conditions.Applications.IncludeApplications.Count -eq 1 -and $policy.Conditions.Applications.IncludeApplications -contains "All")
    {
        $results.containsAllCloudApps = $true
    }

    $results.containsHighMediumRiskUserLevel = $false
    if ($policy.Conditions.SignInRiskLevels -contains 'high' -and $policy.Conditions.SignInRiskLevels -contains 'medium')
    {
        $results.containsHighMediumRiskUserLevel = $true
    }

    $results.requiresMFA = $false
    if ($policy.GrantControls.BuiltInControls -contains "mfa")
    {
        $results.requiresMFA = $true
    }

    $results.SigninFrequencyEveryTime = $false
    if ($policy.SessionControls.SignInFrequency.FrequencyInterval -contains "everyTime" -and $policy.SessionControls.SignInFrequency.IsEnabled -eq $true)
    {
        $results.SigninFrequencyEveryTime = $true
    }

    $results.enabled = $false
    if ($policy.State -eq $state)
    {
        $results.enabled = $true
    }

    if ($results.ContainsValue($false) -eq $false)
    {
        $correctPolicyFound = $true
    }
}

if ($correctPolicyFound)
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyEnableIdentityProtectionSignin'
        ResourceInstanceName  = 'CIS-5.2.2.7'
        Id                    = 'Enable Identity Protection sign-in risk policies'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicyEnableIdentityProtectionSignin'
        ResourceInstanceName  = 'CIS-5.2.2.7'
        Id                    = 'Enable Identity Protection sign-in risk policies'
        FoundRequiredCAPolicy = $false
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
