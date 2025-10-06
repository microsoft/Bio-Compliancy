Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$users = Get-MgUser -All
$incorrectUsers = foreach ($user in $users)
{
    $results = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/users/$($user.Id)/authentication/requirements" -Method GET
    if ($results.perUserMfaState -eq 'enabled')
    {
        $user.UserPrincipalName
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'AADCustomUserPerUserMFADisabled'
    ResourceInstanceName = "CIS-5.1.2.1"
    Id                   = "Ensure Per-user MFA is disabled"
    IncorrectUsers       = $incorrectUsers
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
