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

$tenantSettings = Get-PnPTenant -ErrorAction SilentlyContinue

$sharingSetting = 'Unknown'
if ($null -ne $tenantSettings)
{
    $sharingSetting = $tenantSettings.SharingCapability.ToString()
    if ($sharingSetting -in @('ExternalUserSharingOnly','ExistingExternalUserSharingOnly','Disabled'))
    {
        $sharingSetting = "ExternalUserSharingOnly (New and existing guests) or more restrictive"
    }
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'SPOCustomSharingSettings'
    ResourceInstanceName = 'CIS-7.2.3'
    Id                   = 'SharePoint External Sharing Setting'
    SharingCapability    = $sharingSetting
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
