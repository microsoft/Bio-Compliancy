BeforeAll {
}

AfterAll {
}

Describe 'Check for presence of all required files' {
    $requiredFiles = @(
        'AllBIOControlDetails.json',
        'AllCISBenchmarkDetails.json',
        'M365-Bio Compliance.pbit',
        'M365ReportBIO.json',
        'PrepBIOServicePrincipal.ps1',
        'PrepEnvironment.ps1',
        'RunBIOAssessment.ps1',
        'RunBIOExport.ps1',
        'SupportFunctions.psm1'
    )

    It "File <_> should be present" -ForEach $requiredFiles {
        $path = Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\$_"
        Test-Path -Path $path | Should -Be $true
    }
}

Describe 'Check custom scripts folder' {
    BeforeAll {
        $path = Join-Path -Path $PSScriptRoot -ChildPath "..\scripts\custom"
    }

    It "Folder Custom should be present" {
        Test-Path -Path $path | Should -Be $true
    }

    It "All files in Custom should be ps1 files" {
        $customFiles = Get-ChildItem -Path $path
        foreach ($file in $customFiles)
        {
            $file.Name | Should -BeLike '*.ps1'
        }
    }
}
