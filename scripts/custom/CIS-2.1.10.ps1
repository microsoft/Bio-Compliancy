Write-LogEntry -Message "Executing $($MyInvocation.MyCommand.Name)"

$null = New-M365DSCConnection -Workload 'MicrosoftGraph' `
    -InboundParameters @{
        ApplicationId = $ApplicationId
        TenantId = $TenantId
        CertificateThumbprint = $CertificateThumbprint
    }

$domains = Get-MgBetaDomain
$incorrectDMARC = foreach ($domain in $domains)
{
    $record = Resolve-DnsName -Name "_dmarc.$($domain.Id)" -Type TXT -ErrorAction SilentlyContinue
    if ($null -eq $record)
    {
        "$($domain.Id) -> No DMARC"
    }
    else
    {
        $foundDMARC = $true
        foreach ($dmarc in $record.Strings)
        {
            if ($dmarc -notmatch 'p=quarantine' -and $dmarc -notmatch 'p=reject')
            {
                $foundDMARC = $false
            }

            if ($dmarc -notmatch 'rua=mailto:' -or $dmarc -notmatch 'ruf=mailto:')
            {
                $foundDMARC = $false
            }
        }

        if ($foundDMARC -eq $false)
        {
            "$($domain.Id) -> Incorrect DMARC ($($record.Strings))"
        }
    }
}

if ($null -eq $incorrectDMARC)
{
    $incorrectDMARC = @()
}

$script:exportResults += [PSCustomObject]@{
    ResourceName         = 'EXOCustomDMARCRecords'
    ResourceInstanceName = 'CIS-2.1.10'
    Id                   = 'DMARC records published for all domains'
    IncorrectDomains     = $incorrectDMARC
}

Write-LogEntry -Message "Completed $($MyInvocation.MyCommand.Name)"
