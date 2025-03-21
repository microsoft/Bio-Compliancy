# Changelog for Microsoft 365 BIO Compliancy Template

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added PowerShell #requires statement to all scripts to make sure the script
  is always executed as an administrator.
- Added check if Windows Remoting has been configured or not and configure
  when it is not.
- Added check for a successful conversion of the export to JSON format.
- Added check for minimum Microsoft365DSC version to be used.
- Added versioning to the solution. The used version is now shown on the
  screen when the scripts are executed.
- Increased CIS Benchmark coverage, adding checks for all missing controls.
- Added documentation of CIS Benchmark coverage, added to this repository.
- Added creation of output transcript to a Logs folder.
- Added removal of CIMInstance properties to the script.

### Changed

- Upgraded to CIS Benchmark for Microsoft 365 v4.0.0.

## [2.2.0-R01] - 2024-06-25

### Added

- Released first version of the Microsoft 365 BIO Compliancy template
