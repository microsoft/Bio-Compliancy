Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId         = $ApplicationId
        TenantId              = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$authPolicy = Get-MgBetaPolicyAuthorizationPolicy
$currentPermissions = $authPolicy.PermissionGrantPolicyIdsAssignedToDefaultUserRole
$incorrectPermissions = @()
if ($currentPermissions -contains 'ManagePermissionGrantsForSelf.microsoft-user-default-low' -or $currentPermissions -contains 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy')
{
    $incorrectPermissions = $currentPermissions
}

$script:exportResults += [PSCustomObject]@{
    ResourceName                                      = 'AADCustomAuthorizationPolicy'
    ResourceInstanceName                              = 'CIS-5.1.5.1'
    Id                                                = 'Ensure user consent to apps accessing company data on their behalf is not allowed'
    PermissionGrantPolicyIdsAssignedToDefaultUserRole = $incorrectPermissions
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
