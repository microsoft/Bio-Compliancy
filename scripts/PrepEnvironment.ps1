<#
.SYNOPSIS
    This script installs all required components, so the environment is ready for the follow-up scripts.

.DESCRIPTION
    This script installs all required components, so the environment is ready for the follow-up scripts.
    The script is using Mirosoft365DSC and will install the latest version. When Microsoft365DSC is already present,
    it will ask the user to upgrade to the most recent version. If the script is running in an unattended session,
    it will use installed version.

.EXAMPLE
    .\PrepEnvironment.ps1

.NOTES
    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/

    For more information about "Microsoft365DSC" (M365DSC), see:
    https://microsoft365dsc.com
#>
[CmdletBinding()]
param
()

begin
{
    $origProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $workingDirectory = $PSScriptRoot
    try
    {
        Import-Module -Name (Join-Path -Path $workingDirectory -ChildPath 'SupportFunctions.psm1') -ErrorAction Stop
    }
    catch
    {
        Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim('.')). Exiting." -ForegroundColor Red
        $ProgressPreference = $origProgressPreference
        exit -1
    }

    Write-LogEntry -Object "Starting Preparation script"
    Set-Location -Path $workingDirectory
}

process
{
    Write-LogEntry -Object "Checking presence of Microsoft365DSC"
    $m365dscModule = Get-Module Microsoft365DSC -ListAvailable
    if ($null -eq $m365dscModule)
    {
        Write-LogEntry -Object "Installing Microsoft365DSC"
        Install-Module Microsoft365DSC
    }
    else
    {
        Write-LogEntry -Object "Microsoft365DSC already installed: $($m365dscModule.Version)"

        $newestModule = Find-Module Microsoft365DSC
        if ($newestModule.Version -gt $m365dscModule.Version)
        {
            if ((Assert-IsNonInteractiveShell) -eq $false)
            {
                $top = new-Object System.Windows.Forms.Form -property @{Topmost=$true}
                $result = [System.Windows.Forms.MessageBox]::Show($top,"Do you want to upgrade to the most recent version of Microsoft365DSC ($($newestModule.Version))","Do you want to upgrade?",'YesNo','Question')
                if ($result -eq 'Yes')
                {
                    Write-LogEntry -Object "Upgrading Microsoft365DSC to v$($newestModule.Version)"
                    Remove-Item -Path (Split-Path -Path $m365dscModule.Path -Parent) -Recurse -Force
                    Install-Module Microsoft365DSC
                }
                else
                {
                    Write-LogEntry -Object "Keep using current version of Microsoft365DSC."
                }
            }
        }
    }

    $m365dscModule = Get-Module Microsoft365DSC -ListAvailable
    if ($null -eq $m365dscModule)
    {
        Write-LogEntry -Object "Microsoft365DSC not installed successfully. Exiting!" -Failure
        return
    }

    Write-LogEntry -Object "Updating Microsoft365DSC dependencies"
    Update-M365DSCDependencies

    Write-LogEntry -Object "Removing duplicate versions of the dependencies (to prevent conflicts)"
    Uninstall-M365DSCOutdatedDependencies
}

end
{
    $ProgressPreference = $origProgressPreference

    Write-LogEntry -Object "Completed Preparation script"
}
