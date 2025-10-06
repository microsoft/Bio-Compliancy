Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$auth = Get-MgBetaPolicyAuthenticationMethodPolicy

$incorrectMethods = @()
foreach ($method in @('Email', 'Sms', 'Voice'))
{
    $state = ($auth.AuthenticationMethodConfigurations | Where-Object -FilterScript { $_.Id -eq $method}).State
    if ($state -ne 'disabled')
    {
        $incorrectMethods += $method
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName           = 'AADCustomWeakAuthenticationMethodsDisabled'
    ResourceInstanceName   = 'CIS-5.2.3.5'
    Id                     = 'Ensure weak authentication methods are disabled'
    EnabledWeakAuthMethods = $incorrectMethods
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
