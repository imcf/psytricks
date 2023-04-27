# PSyTricks Change Log

<!-- markdownlint-disable MD024 (no-duplicate-header) -->

## 1.1.0

### Added

* Mapping for the `Action` item when requesting a `poweraction`.

## 1.0.0

### Changed

* 🧨 **BREAKING** 🧨
  * The *PowerShell* wrapper script parameter `JsonConfig` has been dropped in
    favor of the new `AdminAddress` that gives the address of the Delivery
    Controller to use directly. This is done for two reasons: to be more
    consistent with the original Citrix commands and to get rid of the overhead
    of needing an extra file when it contains only one single setting.
  * To accommodate for this, the `PSyTricksWrapper` constructor changed its
    only parameter from `conffile` to `deliverycontroller`.
  * Along those lines also the CLI tool switched from using the parameter
    `--config` to `--cdc` (short for *Citrix Delivery Controller*).
* When requesting session details (`PSyTricksWrapper.get_sessions`) the
  following properties will now also be reported:
  * `ClientAddress`
  * `ClientName`
  * `ClientPlatform`
  * `ClientProductId`
  * `ClientVersion`
  * `ConnectedViaHostName`

### Added

* Two new arguments for the command line tool:
  * `--version`
  * `--outfile` - to write the results into a file

## 0.1.0

### Added

* Implementation of CLI commands and related wrapper methods (in braces):
  * `getaccess` (`get_access_users()`)
  * `setaccess` (`set_access_users()`)
  * `maintenance` (`set_maintenance()`)
  * `sendmessage` (`send_message()`)
  * `poweraction` (`perform_poweraction()`)

### Changed

* Various `*State` fields reported by Citrix are now being mapped from numerical
  values to their descriptive (*human readable*) names, just as PowerShell does
  it when converting the resulting objects to text (e.g. for console output).
* In case of an error while parsing the JSON returned by the PS1 script the raw
  data is now included in the error message.
* Machine properties now contain the `DNSName` field.
* Session properties now contain the `Uid` field.

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
