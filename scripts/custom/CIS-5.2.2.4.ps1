Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}

$requiredRoles = @(
    'Application administrator',
    'Authentication administrator',
    'Billing administrator',
    'Cloud application administrator',
    'Conditional Access administrator',
    'Exchange administrator',
    'Global administrator',
    'Global reader',
    'Helpdesk administrator',
    'Password administrator',
    'Privileged authentication administrator',
    'Privileged role administrator',
    'Security administrator',
    'SharePoint administrator',
    'User administrator'
)

$allRoles = Get-MgBetaDirectoryRoleTemplate -All

$roleLookup = @{}
foreach ($role in $allRoles)
{
    $roleLookup[$role.DisplayName] = $role.Id
}

$policies = Get-MgBetaIdentityConditionalAccessPolicy

$state = 'enabled' #'enabledForReportingButNotEnforced'

$correctPolicyFound = $false
foreach ($policy in $policies)
{
    $results = @{}

    $results.allRolesCovered = $true
    foreach ($requiredRole in $requiredRoles)
    {
        if ($roleLookup[$requiredRole] -notin $policy.Conditions.Users.IncludeRoles)
        {
            $results.allRolesCovered = $false
        }
    }

    $results.signinFrequencyCorrect = $false
    if ($policy.SessionControls.SignInFrequency.Type -eq 'hours' -and $policy.SessionControls.SignInFrequency.Value -le 4)
    {
        $results.signinFrequencyCorrect = $true
    }

    $results.persistentBrowserNever = $false
    if ($policy.SessionControls.PersistentBrowser.IsEnabled -eq $true -and $policy.SessionControls.PersistentBrowser.Mode -eq 'never')
    {
        $results.persistentBrowserNever = $true
    }

    $results.requiresMFA = $false
    if ($policy.GrantControls.BuiltInControls -contains "mfa")
    {
        $results.requiresMFA = $true
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
        ResourceName          = 'AADCustomConditionalAccessPolicySignInFrequencyEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.4'
        Id                    = 'Ensure Sign-in frequency is enabled and browser sessions are not persistent for Administrative users'
        FoundRequiredCAPolicy = $true
    }
}
else
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName          = 'AADCustomConditionalAccessPolicySignInFrequencyEnabledForAdmins'
        ResourceInstanceName  = 'CIS-5.2.2.4'
        Id                    = 'Ensure Sign-in frequency is enabled and browser sessions are not persistent for Administrative users'
        FoundRequiredCAPolicy = $
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
