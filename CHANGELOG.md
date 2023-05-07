# PSyTricks Change Log

<!-- markdownlint-disable MD024 (no-duplicate-header) -->

## 2.0.0

### Common

A `REST` server ([`restricks-server.ps1`][restricks]) written in PowerShell was
added to facilitate and speed up interaction with the CVAD / Citrix toolstack.
See the installation instructions for details on how to use it and please be
aware that this is very much in an infant state 🍼.

NOTE: this is an *alternative* to the original way of calling PowerShell as a
Python `subprocess` (requiring the Python code to be executed in a user context
that has access to the `Citrix Broker` Snap-In and that has appropriate
permissions configured on the *Delivery Controller*). Wrapping this into a REST
service that is reachable via HTTP allows to run the Python code in a completely
independent context.

### Changed

* 🧨 **BREAKING** 🧨
  * `psytricks.wrapper.PSyTricksWrapper.send_message` is now requiring the
    details (style, title and text) of the message to send directly, unlike
    before where a file was being read. If the file use-case is required again
    it can be simply wrapped around the method call. This change is done to
    keep consistency with the newly introduced `REST` wrapper class (see below).
  * All *action* methods (requesting data or state changes from Citrix) in
    `psytricks.wrapper.PSyTricksWrapper` have dropped the `kwargs` parameter.
    They were initially implemented to simplify the call from within
    `psytricks.cli.run_cli` but are basically just adding confusion.
  * To accommodate for the above changes the **CLI** command `sendmessage` now
    has two additional command-line options: `--title` (mandatory) to set the
    message title and `--style` (optional) to set the message icon. The
    previously existing `--message` option now expects the body as a string (may
    contain `\n` for linebreaks), not the path to a message file any more.

### Added

* An additional wrapper class `psytricks.wrapper.ResTricksWrapper` 🎪 has been
  added to interface with the newly introduced REST service. Apart from feeling
  much less awkward than the `subprocess` way, this also happens to be orders of
  magnitude faster 🎢🎡.
* Add `psytricks.literals` to improve type checking and documentation.

## 1.1.0

### Added

* Mapping for the `Action` item when requesting a `poweraction` (see
  `psytricks.mappings` for details).

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

[restricks]: https://github.com/imcf/psytricks/tree/main/src/psytricks/ps1scripts
