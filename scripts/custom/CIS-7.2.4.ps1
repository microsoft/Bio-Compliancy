Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'PnP' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

<#
Additional information:
- ExternalUserAndGuestSharing     : Anyone
- ExternalUserSharingOnly         : New and existing guests
- ExistingExternalUserSharingOnly : Existing guests
- Disabled                        : Only people in your organization

Source: https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off#which-option-to-select
#>

$mySite = Get-PnPTenantSite -Filter "Url -like '-my.sharepoint.'" -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.Template -notmatch '^RedirectSite#' }

$sharingSetting = 'Unknown'
if ($null -ne $mySite)
{
    $mySiteTenantSite = Get-PnPTenantSite -Identity $mySite.Url -ErrorAction SilentlyContinue
    if ($null -ne $mySiteTenantSite)
    {
        $sharingSetting = $mySiteTenantSite.SharingCapability.ToString()
        if ($sharingSetting -in @('ExternalUserSharingOnly','ExistingExternalUserSharingOnly','Disabled'))
        {
            $sharingSetting = "ExternalUserSharingOnly (New and existing guests) or more restrictive"
        }
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'SPOCustomODSharingSettings'
    ResourceInstanceName = 'CIS-7.2.4'
    Id                   = 'SharePoint External OneDrive Sharing Setting'
    SharingCapability    = $sharingSetting
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
