Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'PnP' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$tenantSettings = Get-PnPTenant

$authDaysLessThan15 = $false
if ($tenantSettings.EmailAttestationReAuthDays -le 15)
{
    $authDaysLessThan15 = $true
}

$script:exportResults += [PSCustomObject]@{
    ResourceName            = 'SPOCustomReauthenticationWithCodeRestricted'
    ResourceInstanceName    = 'CIS-7.2.10'
    Id                      = 'Ensure reauthentication with verification code is restricted'
    Required                = $tenantSettings.EmailAttestationRequired
    AuthenticationMax15Days = $authDaysLessThan15
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
