<#
.SYNOPSIS
    This script compares the configuration of a Microsoft 365 tenant with the BIO baseline and reports on the compliance.

.DESCRIPTION
    This script compares the current configuration of a Microsoft 365 tenant with the BIO baseline. It is using a Microsoft365DSC
    export and compares the results with the BIO baseline.

    It generates three files:
        - Results_BIOControls.json: Overview of the BIO controls and what resources match and which don't.
        - Results_BIOControlsOverview.csv: Detailed overview of each measurement, their respective BIO Control and the current score.
        - Results_Comparison.json: Summary of the compliancy of each resource with the BIO baseline and what properties do not match.

.EXAMPLE
    .\RunBIOAssessment.ps1

.NOTES
    More information about running this assessment can be found at:
    https://github.com/microsoft/Bio-Compliancy/blob/main/README.md

    For more information about "Baseline Informatiebeveiliging Overheid" (BIO), see:
    https://www.digitaleoverheid.nl/overzicht-van-alle-onderwerpen/cybersecurity/kaders-voor-cybersecurity/baseline-informatiebeveiliging-overheid/
#>
[CmdletBinding()]
param
()

# ----------------- START SCRIPT -----------------
begin
{
    function Test-Value
    {
        [CmdletBinding()]
        [OutputType([System.Boolean])]
        param (
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            [AllowNull()]
            [System.Object]
            $Reference,

            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [AllowEmptyString()]
            [AllowNull()]
            [System.Object]
            $Difference
        )

        $testResult = $true
        if ($Reference -is [System.Array] -or $Difference -is [System.Array])
        {
            $testResult = Test-Array -Reference $Reference -Difference $Difference
        }
        elseif ($Reference -ne $Difference)
        {
            $testResult = $false
        }

        return $testResult
    }

    function Test-Array
    {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [AllowNull()]
            [System.Array]
            $Reference,

            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [AllowNull()]
            [System.Array]
            $Difference
        )

        $testResult = $true

        # NOTE: If there are no nested array objects, we can use Compare-Object instead of the foreach loop.
        # Compare-Object has better performance.

        foreach ($item in $Reference)
        {
            switch ($item.GetType().FullName)
            {
                'System.Collections.Hashtable'
                {
                    # NOT YET IMPLEMENTED
                    break
                }
                'System.Array'
                {
                    # NOT YET IMPLEMENTED
                    break
                }
                Default
                {
                    if ($item -notin $Difference)
                    {
                        Write-LogEntry -Object "Could not find [$item] in Difference" -Verbose
                        $testResult = $false
                        break
                    }
                }
            }
        }

        return $testResult
    }

    $currWarningPreference = $WarningPreference
    $WarningPreference = 'SilentlyContinue'

    $currProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $workingDirectory = $PSScriptRoot
    try
    {
        Import-Module -Name (Join-Path -Path $workingDirectory -ChildPath 'SupportFunctions.psm1') -ErrorAction Stop
    }
    catch
    {
        Write-Host "ERROR: Could not load library 'SupportFunctions.psm1'. $($_.Exception.Message.Trim('.')). Exiting." -ForegroundColor Red

        $WarningPreference = $currWarningPreference
        $ProgressPreference = $currProgressPreference

        exit -1
    }

    Write-LogEntry -Object 'Starting BIO Comparison script'
    Set-Location -Path $workingDirectory
}

process
{
    # Create variables to store comparison results
    $comparisonResults = @()
    $bioControlsResults = @{}
    $detailedBIOControlsResults = @()

    $timestamp = Get-Date -f 'yyyyMMdd'
    $outputFolder = Join-Path -Path $workingDirectory -ChildPath "Output\$timestamp"

    $bioSettingsFileName = 'M365ReportBIO.JSON'
    $bioSettingsFullPath = Join-Path -Path $workingDirectory -ChildPath $bioSettingsFileName

    $currentSettingsFileName = 'M365Report.JSON'
    $currentSettingsFullPath = Join-Path -Path $outputFolder -ChildPath $currentSettingsFileName

    $bioControlsDetailsCSV = 'BIOControlsDetails.csv'

    $resultComparisonFileName = 'Results_Comparison.json'
    $resultComparisonFullPath = Join-Path -Path $outputFolder -ChildPath $resultComparisonFileName

    $resultBIOControlsFileName = 'Results_BIOControls.json'
    $resultBIOControlsFullPath = Join-Path -Path $outputFolder -ChildPath $resultBIOControlsFileName

    $resultRulesCSVFileName = 'Results_BIOControlsOverview.csv'
    $resultRulesCSVFullPath = Join-Path -Path $outputFolder -ChildPath $resultRulesCSVFileName

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ((Test-Path -Path $outputFolder) -eq $false)
    {
        Write-LogEntry -Object "Could not find path '$outputFolder'. Please make sure folder exists." -Failure
        return
    }

    # By default, the script uses the supplied JSON file. If the -Debug switch is used, the script will try to convert the PS1
    # into a JSON file.
    if ($Debug)
    {
        Write-LogEntry -Object 'Convert M365DSC configuration to JSON'
        if (Test-Path -Path '.\BIOBlueprint.ps1')
        {
            New-M365DSCReportFromConfiguration -Type 'JSON' -ConfigurationPath '.\BIOBlueprint.ps1' -OutputPath $bioSettingsFullPath
        }
        else
        {
            Write-LogEntry -Object "Could not find BIOBlueprint.ps1. Using current $bioSettingsFullPath." -Failure
        }
    }

    # Read the Source JSON files
    Write-LogEntry -Object "Read and parse BIO Baseline file: $bioSettingsFullPath"
    if (Test-Path -Path $bioSettingsFullPath)
    {
        $bioJson = Get-Content -Raw -Path $bioSettingsFullPath | ConvertFrom-Json
    }
    else
    {
        Write-LogEntry -Object "Cannot find BIO Baseline file '$bioSettingsFullPath'. Exiting script." -Failure
        return
    }

    Write-LogEntry -Object "Read and parse export configuration: $currentSettingsFullPath"
    if (Test-Path -Path $currentSettingsFullPath)
    {
        $currentJson = Get-Content -Raw -Path $currentSettingsFullPath | ConvertFrom-Json
    }
    else
    {
        Write-LogEntry -Object "Cannot find current settings file '$currentSettingsFullPath'. Exiting script." -Failure
        return
    }

    Write-LogEntry -Object "Read BIO Controls details: $bioControlsDetailsCSV"
    if (Test-Path -Path ".\$bioControlsDetailsCSV")
    {
        $bioControlsDetails = Import-Csv -Path ".\$bioControlsDetailsCSV" -Delimiter ';' -Encoding UTF8
    }
    else
    {
        Write-LogEntry -Object "Cannot find current settings file '$bioControlsDetailsCSV'. Exiting script." -Failure
        return
    }

    Write-LogEntry -Object 'Comparing current settings with BIO Baseline'
    foreach ($bioObject in $bioJson)
    {
        $bioResourceName = $bioObject.ResourceName
        $currentObjects = $currentJson | Where-Object { $_.ResourceName -eq $bioResourceName }

        if ($currentObjects)
        {
            Write-LogEntry -Object "Processing resource $($bioResourceName)" -Verbose
            foreach ($currentObject in $currentObjects)
            {
                $propertyDifferences = @()
                $propertiesMatch = $true

                foreach ($property in $bioObject.PSObject.Properties)
                {
                    $propertyName = $property.Name
                    if ($propertyName -notin 'ResourceName', 'ResourceInstanceName', 'DisplayName', 'Id', 'Identity', 'BIOControls')
                    {
                        $bioValue = $property.Value
                        $currentValue = $currentObject.$propertyName

                        $testResult = Test-Value -Reference $bioValue -Difference $currentValue
                        Write-LogEntry -Object "Testing $($propertyName): BIO [$($bioValue -join ', ')], Current[$($currentValue -join ', ')], Result[$testResult]" -Verbose
                        if ($testResult -eq $false)
                        {
                            $propertiesMatch = $false

                            [String]$consolidatedBioValue = $bioValue
                            if ($bioValue -is [Array])
                            {
                                $consolidatedBioValue = ($bioValue | Sort-Object) -join ", "
                            }

                            [String]$consolidatedCurrentValue = $currentValue
                            if ($currentValue -is [Array])
                            {
                                $consolidatedCurrentValue = ($currentValue | Sort-Object) -join ", "
                            }

                            $propertyDifferences += [PSCustomObject]@{
                                PropertyName = $propertyName
                                BIO          = $consolidatedBioValue
                                Current      = $consolidatedCurrentValue
                            }
                        }
                    }
                }

                $comparisonResults += [PSCustomObject]@{
                    ReferenceResourceName         = $bioObject.ResourceName
                    ReferenceResourceInstanceName = $bioObject.ResourceInstanceName
                    TargetResourceName            = $currentObject.ResourceName
                    TargetResourceInstanceName    = $currentObject.ResourceInstanceName
                    PropertiesMatch               = $propertiesMatch
                    PropertyDifferences           = $propertyDifferences
                }

                $measureCount = 1
                if ($propertiesMatch -eq $false)
                {
                    $measureCount = 0
                }

                if ($bioObject.BIOControls)
                {
                    $sourceBIOControls = $bioObject.BIOControls
                    foreach ($control in $sourceBIOControls)
                    {
                        $bioControlsResult = $bioControlsResults[$control]

                        if ($null -eq $bioControlsResult)
                        {
                            $bioControlsResult = [PSCustomObject]@{
                                BIOControls   = $control
                                MeasuresCount = 0
                                CoveredBy     = @()
                                Matched       = 0
                                Unmatched     = 0
                                TotalMissing  = 0
                                Matches       = @()
                                Unmatches     = @()
                                Missing       = @()
                            }
                        }

                        if ($bioControlsResult.CoveredBy.ResourceName -notcontains $bioObject.ResourceName -or $bioControlsResult.CoveredBy.ResourceInstanceName -notcontains $bioObject.ResourceInstanceName)
                        {
                            $bioControlsResult.CoveredBy += $bioObject
                            $bioControlsResult.MeasuresCount++
                        }

                        if ($propertiesMatch)
                        {
                            $bioControlsResult.Matched++
                            $bioControlsResult.Matches += [PSCustomObject]@{
                                TargetResourceName         = $currentObject.ResourceName
                                TargetResourceInstanceName = $currentObject.ResourceInstanceName
                            }
                        }
                        else
                        {
                            $bioControlsResult.Unmatched++
                            $bioControlsResult.Unmatches += [PSCustomObject]@{
                                TargetResourceName         = $currentObject.ResourceName
                                TargetResourceInstanceName = $currentObject.ResourceInstanceName
                            }
                        }
                        $bioControlsResults[$control] = $bioControlsResult

                        $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

                        $detailedBIOControlsResults += [PSCustomObject]@{
                            ControlNr            = $control
                            Category             = $controlDetails.Category
                            BBN                  = $controlDetails.BBN
                            Title                = $controlDetails.Title
                            Description          = $controlDetails.Description
                            ResourceName         = $currentObject.ResourceName
                            ResourceInstanceName = $currentObject.ResourceInstanceName
                            CISNumber            = $bioObject.ResourceInstanceName
                            MeasuresCount        = 1
                            Score                = $measureCount
                            Timestamp            = $timestamp
                            RequiredMeasure      = $controlDetails.'Government Measure'
                        }
                    }
                }
                else
                {
                    $detailedBIOControlsResults += [PSCustomObject]@{
                        ControlNr            = '0'
                        Category             = 'General Recommended Practice'
                        BBN                  = '0'
                        Title                = 'General Recommended Practice'
                        Description          = 'General Recommended Practice'
                        ResourceName         = $currentObject.ResourceName
                        ResourceInstanceName = $currentObject.ResourceInstanceName
                        CISNumber            = $bioObject.ResourceInstanceName
                        MeasuresCount        = 1
                        Score                = $measureCount
                        Timestamp            = $timestamp
                        RequiredMeasure      = 'N/A'
                    }
                }
            }
        }
        else
        {
            Write-LogEntry -Object "Processing resource $($bioResourceName): Resource not found in current configuration" -Verbose

            $comparisonResults += [PSCustomObject]@{
                ReferenceResourceName         = $bioObject.ResourceName
                ReferenceResourceInstanceName = $bioObject.ResourceInstanceName
                TargetResourceName            = 'Missing'
                TargetResourceInstanceName    = 'Missing'
                PropertiesMatch               = 0
                PropertyDifferences           = @(
                    @{
                        PropertyName = 'Resource missing in the current configuration'
                        BIO = ""
                        Current = ""
                    }
                )
            }

            if ($bioObject.BIOControls)
            {
                $sourceBIOControls = $bioObject.BIOControls
                foreach ($control in $sourceBIOControls)
                {
                    $bioControlsResult = $bioControlsResults[$control]

                    if ($null -eq $bioControlsResult)
                    {
                        $bioControlsResult = [PSCustomObject]@{
                            BIOControls   = $control
                            MeasuresCount = 0
                            CoveredBy     = @()
                            Matched       = 0
                            Unmatched     = 0
                            TotalMissing  = 0
                            Matches       = @()
                            Unmatches     = @()
                            Missing       = @()
                        }
                    }

                    if ($bioControlsResult.CoveredBy.ResourceName -notcontains $bioObject.ResourceName -or $bioControlsResult.CoveredBy.ResourceInstanceName -notcontains $bioObject.ResourceInstanceName)
                    {
                        $bioControlsResult.CoveredBy += $bioObject
                        $bioControlsResult.MeasuresCount++
                    }

                    $bioControlsResult.TotalMissing++
                    $bioControlsResult.Missing += [PSCustomObject]@{
                        TargetResourceName         = $bioObject.ResourceName
                        TargetResourceInstanceName = $bioObject.ResourceInstanceName
                    }

                    $bioControlsResults[$control] = $bioControlsResult

                    $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

                    $detailedBIOControlsResults += [PSCustomObject]@{
                        ControlNr            = $control
                        Category             = $controlDetails.Category
                        BBN                  = $controlDetails.BBN
                        Title                = $controlDetails.Title
                        Description          = $controlDetails.Description
                        ResourceName         = $bioObject.ResourceName
                        ResourceInstanceName = 'MeasureMissingInExport'
                        CISNumber            = $bioObject.ResourceInstanceName
                        MeasuresCount        = 1
                        Score                = 0
                        Timestamp            = $timestamp
                        RequiredMeasure      = $controlDetails.'Government Measure'
                    }
                }
            }
            else
            {
                $detailedBIOControlsResults += [PSCustomObject]@{
                    ControlNr            = '0'
                    Category             = 'General Recommended Practice'
                    BBN                  = '0'
                    Title                = 'General Recommended Practice'
                    Description          = 'General Recommended Practice'
                    ResourceName         = $currentObject.ResourceName
                    ResourceInstanceName = 'MeasureMissingInExport'
                    CISNumber            = $bioObject.ResourceInstanceName
                    MeasuresCount        = 1
                    Score                = 0
                    Timestamp            = $timestamp
                    RequiredMeasure      = 'N/A'
                }
            }
        }
    }

    <#
    # Disabled because the M365 BIO template doesn't cover all BIO Controls and therefore will always show missing controls.
    Write-LogEntry -Object 'Checking for BIO Controls that are not covered'
    $diff = Compare-Object -ReferenceObject ( $detailedBIOControlsResults.ControlNr | Sort-Object -Unique) -DifferenceObject ($bioControlsDetails.ControlNr)
    $unprocessedControls = $diff | Where-Object { $_.SideIndicator -eq '=>' }
    if ($unprocessedControls.Count -gt 0)
    {
        foreach ($control in $unprocessedControls.InputObject)
        {
            $controlDetails = $bioControlsDetails | Where-Object -FilterScript { $_.ControlNr -eq $control }

            $detailedBIOControlsResults += [PSCustomObject]@{
                ControlNr            = $control
                Category             = $controlDetails.Category
                BBN                  = $controlDetails.BBN
                Title                = $controlDetails.Title
                Description          = $controlDetails.Description
                ResourceName         = 'N/A'
                ResourceInstanceName = 'ControlMissingInExport'
                CISNumber            = 'N/A'
                MeasuresCount        = 0
                Score                = 0
                Timestamp            = $timestamp
                RequiredMeasure      = $controlDetails.'Government Measure'
            }
        }
    }
    #>

    Write-LogEntry -Object 'Completed comparing current settings with BIO Baseline'

    # Export comparison results to a JSON file
    Write-LogEntry -Object "Saving Comparison results to $resultComparisonFullPath"
    $comparisonResults | ConvertTo-Json -Depth 10 | Set-Content -Path $resultComparisonFullPath

    # Export BIOControls-related results to a JSON file
    Write-LogEntry -Object "Saving BIOControls-related results to $resultBIOControlsFullPath"
    $bioControlsResults.Values | ConvertTo-Json -Depth 10 | Set-Content -Path $resultBIOControlsFullPath

    # Export Detailed BIOControls-related results to a CSV file
    Write-LogEntry -Object "Saving Detailed BIOControls-related results to $resultRulesCSVFullPath"
    $detailedBIOControlsResults | Export-Csv -Path $resultRulesCSVFullPath -Delimiter ';' -Encoding UTF8 -NoTypeInformation

    # Display a message indicating the exports
    Write-LogEntry -Object 'Comparison results exported to comparison_results.json'
    Write-LogEntry -Object 'BIOControls-related results exported to biocontrols_results.json'
}

end
{
    $WarningPreference = $currWarningPreference
    $ProgressPreference = $currProgressPreference

    Write-LogEntry -Object 'Completed BIO Comparison script'
}
