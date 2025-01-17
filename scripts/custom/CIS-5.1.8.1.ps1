Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantName
        CertificateThumbprint = $CertificateThumbprint
    }

$orgSettings = Get-MgBetaOrganization

$syncCorrect = $false
if ($null -ne $orgSettings.OnPremisesSyncEnabled)
{
    if ($orgSettings.OnPremisesSyncEnabled -eq $true)
    {
        # Sync is configured, checking if the sync was succesful in the past 24 hours
        if ($orgSettings.OnPremisesLastPasswordSyncDateTime -gt (Get-Date).AddDays(-1))
        {
            # Sync was succesful in the past 24 hours
            $syncCorrect = $true
        }
    }
    else
    {
        # Sync was configured, but that is no longer the case.
        $syncCorrect = $true
    }
}
else
{
    # Sync is not configured, so password are not relevant.
    $syncCorrect = $true
}

$script:exportResults += [PSCustomObject]@{
    ResourceName             = 'AADCustomPasswordHashSync'
    ResourceInstanceName     = 'CIS-5.1.8.1'
    Id                       = 'Password hash sync is enabled'
    SyncConfiguredAndEnabled = $syncCorrect
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
