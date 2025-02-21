Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$domains = Get-MgBetaDomain
[Array]$incorrectSPF = @()
$incorrectSPF = foreach ($domain in $domains)
{
    $record = Resolve-DnsName -Name $domain.Id -Type TXT -ErrorAction SilentlyContinue | Where-Object -FilterScript { $_.Strings -like 'v=spf1*' }
    if ($null -eq $record)
    {
        "$($domain.Id) -> No SPF"
    }
    else
    {
        $foundSPF = $false
        foreach ($spf in $record.Strings)
        {
            if ($spf -match 'include:spf.protection.outlook.com')
            {
                $foundSPF = $true
            }
        }

        if ($foundSPF -eq $false)
        {
            "$($domain.Id) -> Incorrect SPF ($($record.Strings))"
        }
    }
}

if ($null -eq $incorrectSPF)
{
    $incorrectSPF = @()
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomSPFRecords'
    ResourceInstanceName = 'CIS-2.1.8'
    Id                   = 'SPF records published for all domains'
    IncorrectDomains     = $incorrectSPF
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
