Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$mailboxAuditAssociations = Get-MailboxAuditBypassAssociation -ResultSize unlimited -WarningAction SilentlyContinue
$mailboxWithAuditBypassEnabled = $mailboxAuditAssociations | Where-Object { $_.AuditBypassEnabled -eq $true }
if ($null -eq $mailboxWithAuditBypassEnabled)
{
    $failedMailboxes = @()
}
else
{
    $failedMailboxes = $mailboxWithAuditBypassEnabled.Name
}

$script:exportResults += [PSCustomObject]@{
    ResourceName                    = 'EXOCustomAuditBypassEnabled'
    ResourceInstanceName            = 'CIS-6.1.4'
    Id                              = 'Ensure AuditBypassEnabled is not enabled on mailboxes'
    MailboxesWithAuditBypassEnabled = $failedMailboxes
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
