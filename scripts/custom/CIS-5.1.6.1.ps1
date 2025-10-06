Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
    ApplicationId         = $ApplicationId
    TenantId              = $TenantId
    CertificateThumbprint = $CertificateThumbprint
}

$result = Invoke-MgGraphRequest -Uri https://graph.microsoft.com/beta/legacy/policies
$definition = $result.value.definition | ConvertFrom-Json

$domains = @()
if ($null -ne $definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy)
{
    $policyValue = 'Unknown'
    if ($definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy.PSObject.Properties | Where-Object { $_.Name -eq 'BlockedDomains' })
    {
        $domains = $definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy.BlockedDomains
        if ($domains.Count -eq 0)
        {
            $policyValue = 'AllowAnyDomains'
        }
        else
        {
            $policyValue = 'DenySpecifiedDomains'
        }
    }
    elseif ($definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy.PSObject.Properties | Where-Object { $_.Name -eq 'AllowedDomains' })
    {
        $domains = $definition.B2BManagementPolicy.InvitationsAllowedAndBlockedDomainsPolicy.AllowedDomains
        $policyValue = 'AllowOnlySpecifiedDomains'
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName              = 'AADCustomCollaborationInvitationsToAllowedDomains'
    ResourceInstanceName      = 'CIS-5.1.6.1'
    Id                        = 'Ensure that collaboration invitations are sent to allowed domains only'
    CollaborationRestrictions = $policyValue
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
