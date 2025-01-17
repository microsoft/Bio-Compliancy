Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'ExchangeOnline' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantName
        CertificateThumbprint = $CertificateThumbprint
    }

$sharedMailboxes = Get-EXOMailbox -RecipientTypeDetails SharedMailbox

$incorrectMailboxes = foreach ($sharedMailbox in $sharedMailboxes)
{
    $user = Get-MgUser -UserId $sharedMailbox.ExternalDirectoryObjectId -Property DisplayName, UserPrincipalName, AccountEnabled
    if ($user.AccountEnabled -eq $true)
    {
        $user.UserPrincipalName
    }
}

if ($null -eq $incorrectMailboxes)
{
    $incorrectMailboxes = @()
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomSharedMailbox'
    ResourceInstanceName = 'CIS-1.2.2'
    Id                   = 'Sign-in to shared mailboxes is blocked'
    IncorrectMailboxes   = $incorrectMailboxes
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
