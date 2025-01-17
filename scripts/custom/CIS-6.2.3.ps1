Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$externalSenderTaggingSettings = Get-ExternalInOutlook

$externalTaggingEnabled = $externalSenderTaggingSettings.Enabled -eq $true
$allowList = $externalSenderTaggingSettings.AllowList

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomExternalSenderTaggingEnabled'
    ResourceInstanceName = 'CIS-6.2.3'
    Id                   = 'Ensure email from external senders is identified'
    SenderTaggingEnabled = $externalTaggingEnabled
    AllowList            = $allowList.ToArray()
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
