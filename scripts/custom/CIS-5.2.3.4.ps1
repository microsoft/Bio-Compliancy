Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$notMfaCapableUsers = Get-MgBetaReportAuthenticationMethodUserRegistrationDetail -Filter "IsMfaCapable eq false and UserType eq 'Member'" -ErrorAction SilentlyContinue

if ($null -eq $notMfaCapableUsers)
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName         = 'AADCustomUserMFACapable'
        ResourceInstanceName = 'CIS-5.2.3.4'
        Id                   = 'Users not MFA capable: No users'
        MFACapable           = $true
    }
}
else
{
    foreach ($user in $notMfaCapableUsers)
    {
        $userType = if ($user.IsAdmin) { "Admin" } else { "User" }

        $script:exportResults += [PSCustomObject]@{
            ResourceName         = 'AADCustomUserMFACapable'
            ResourceInstanceName = 'CIS-5.2.3.4-{0}-{1}' -f $user.UserPrincipalName, $userType
            Id                   = 'Users not MFA capable: {0}' -f $user.UserPrincipalName
            MFACapable           = $false
        }
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"

