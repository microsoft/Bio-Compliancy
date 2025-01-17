Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantName
        CertificateThumbprint = $CertificateThumbprint
    }

$uri = 'https://graph.microsoft.com/beta/policies/activityBasedTimeoutPolicies'
$result = Invoke-MgGraphRequest -Uri $uri -Method GET
$idleSessionTimeoutConfigured = $false
$idleSessionTimeout3HoursOrLess = $false
if ($result.Value.Count -gt 0)
{
    $policy = $result.Value | Where-Object { $_.IsOrganizationDefault -eq $true }
    if ($null -ne $policy)
    {
        $idleSessionTimeoutConfigured = $true

        $definition = $policy.definition | ConvertFrom-Json
        if ($null -ne $definition.ActivityBasedTimeoutPolicy)
        {
            $application = $definition.ActivityBasedTimeoutPolicy.ApplicationPolicies | Where-Object { $_.ApplicationId -eq 'default' }
            if ($null -ne $application)
            {
                if ([TimeSpan]$application.WebSessionIdleTimeout -le [TimeSpan]'03:00:00')
                {
                    $idleSessionTimeout3HoursOrLess = $true
                }
            }
        }
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName                   = 'O365CustomOrgSettings'
    ResourceInstanceName           = 'CIS-1.3.2'
    Id                             = 'Idle Session Time-out set to 3 hours or less'
    IdleSessionTimeoutConfigured   = $idleSessionTimeoutConfigured
    IdleSessionTimeout3HoursOrLess = $idleSessionTimeout3HoursOrLess
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
