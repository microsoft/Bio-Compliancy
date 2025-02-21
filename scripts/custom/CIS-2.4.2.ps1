Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'ExchangeOnline' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$successfulPolicies = [System.Collections.ArrayList]::new()

$strictMFPol = Get-MalwareFilterPolicy | Where-Object { $_.RecommendedPolicyType -eq "Strict" }
if ($null -ne $strictMFPol)
{
    $null = $successfulPolicies.Add("Anti-Malware")
}

$strictHCFPol = Get-HostedContentFilterPolicy | Where-Object { $_.RecommendedPolicyType -eq "Strict" }
if ($null -ne $strictHCFPol)
{
    $null = $successfulPolicies.Add("Anti-Spam")
}

$strictAPPol = Get-AntiPhishPolicy | Where-Object { $_.RecommendedPolicyType -eq "Strict" }
if ($null -ne $strictAPPol)
{
    $null = $successfulPolicies.Add("Anti-Phishing")
}

$strictSAPol = Get-SafeAttachmentPolicy | Where-Object { $_.RecommendedPolicyType -eq "Strict" }
if ($null -ne $strictSAPol)
{
    $null = $successfulPolicies.Add("Safe Attachments")
}

$strictSLPol = Get-SafeLinksPolicy | Where-Object { $_.RecommendedPolicyType -eq "Strict" }
if ($null -ne $strictSLPol)
{
    $null = $successfulPolicies.Add("Safe Links")
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomStrictPresets'
    ResourceInstanceName = 'CIS-2.4.2'
    Id                   = 'Strict protection presets applied'
    SuccessfulPolicies   = $successfulPolicies.ToArray()
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
