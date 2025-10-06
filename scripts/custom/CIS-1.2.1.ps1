Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$unifiedGroups = Get-MgGroup -Filter "GroupTypes/any(c:c eq 'Unified')" -All -ErrorAction SilentlyContinue
$publicUnifiedGroups = $unifiedGroups | Where-Object { $_.Visibility -eq "Public" }

foreach ($publicGroup in $publicUnifiedGroups)
{
    $script:exportResults += [PSCustomObject]@{
        ResourceName         = 'AADCustomPublicGroup'
        ResourceInstanceName = "CIS-1.2.1-{0}-{1}" -f $publicGroup.DisplayName, $publicGroup.MailNickname
        Id                   = "Public Microsoft 365 Group-{0}" -f $publicGroup.DisplayName
        Visibility           = $publicGroup.Visibility
    }
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
