# PSyTricks Change Log

<!-- markdownlint-disable MD024 (no-duplicate-header) -->

## 0.0.4

### Added

* Implementation of commands:
  * `getaccess`
  * `setaccess`
  * `maintenance`

### Changed

* In case of an error while parsing the JSON returned by the PS1 script the raw
  data is now included in the error message.

## 0.0.3

### Added

* Preliminary implementation of the `disconnect` command.
* Infrastructure for the PowerShell wrapper script for simulating calls to the
  Citrix stack. This is particularly useful for testing (e.g. on Linux) when no
  actual Citrix infrastructure is available.
* Some timing / profiling information is now shown in the debug log.
* Sample JSON data for the `sessions` command.

### Changed

* The *command* CLI argument is now an option, requiring `--command` to be used.
* The JSON returned by the PowerShell wrapepr script now contains two objects
  (`Status` and `Data`), making it possible to return proper exit codes and
  error messages to the calling code.
* Date strings in the JSON formatted by PowerShell 5.1 are now properly parsed
  into Python datetime objects.
* Sample JSON data is now shipped with the module, facilitating debugging and
  testing.
