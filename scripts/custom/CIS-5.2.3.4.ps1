Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$notMfaCapableUsers = Get-MgBetaReportAuthenticationMethodUserRegistrationDetail -Filter "IsMfaCapable eq false and UserType eq 'Member'"

$reportedUsers = foreach ($user in $notMfaCapableUsers)
{
    $isAdmin = if ($user.IsAdmin) { "Admin" } else { "User" }
    $isMfaCapable = if ($user.IsMfaCapable) { "Not MFA Capable" } else { "Not MFA Capable" }
    "{0} / {1} / {2}" -f $user.UserPrincipalName,$isMfaCapable,$isAdmin
}

if ($null -eq $reportedUsers)
{
    $reportedUsers = @()
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'AADCustomUserMFACapable'
    ResourceInstanceName = 'CIS-5.2.3.4'
    Id                   = 'Ensure all member users are MFA capable'
    UsersNotMFACapable   = $reportedUsers
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
