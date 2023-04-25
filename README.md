# PSytricks

`P`ower`S`hell P`y`thon Ci`tri`x Tri`cks`.

Pun intended.

![logo](https://raw.githubusercontent.com/imcf/psytricks/main/resources/images/logo.png)

This package provides an abstraction layer allowing Python code to interact with
a [Citrix Virtual Apps and Desktops (CVAD)][www_cvad] stack, i.e. to fetch
status information and trigger actions on machines and sessions. It does this by
calling a wrapper script written in `Windows PowerShell` (note: **not**
`PowerShell Core`, see below) that is using the *Citrix Broker PowerShell
Snap-In* which is provided along with the `Delivery Controller` installation
media.

## 🤯 Are you serious?

Calling PowerShell as a subprocess from within Python? 😳

To convert results to JSON and pass them back, just to parse it again in Python.
Really? 🧐

### ✅ Yes. We. Are

*And the package name was chosen to reflect this.*

To be very clear: performance is abysmal, but this is *not at all* an issue for
us. Abysmal, as in: for every wrapped call a full (new) PowerShell process needs
to be instantiated, usually taking something like 1-2 seconds. ⏱

However, the frequency of calls is also *very* low in our use case - not more
than a handful per minute, and that's already the peak. Therefore, having a
robust way of interacting with the Citrix platform outnumbers all other
arguments. 🍹

## Installation

### Prerequisites

As mentioned above, the *Citrix Broker PowerShell Snap-In* is required to be
installed on the machine that will run the wrapper script, since its commands
are being used to communicate with the CVAD stack. This is also the reason why
this package will work on ***Windows PowerShell only*** as snap-ins are not
supported on other PowerShell editions. Please note this also implies that the
latest usable PowerShell version is 5.1 as newer ones have dropped support for
snap-ins (but that's a different problem that Citrix will have to solve at some
point).

To install the snap-in, look for an MSI package like this in the `Delivery
Controller` or `XenDesktop` installation media and install it as usual:

* `Broker_PowerShellSnapIn_x64.msi`

### Installing the package

For installing `psytricks` please create a `venv`, then run:

```bash
pip install psytricks
```

This will also register the CLI tool `psytricks.exe` although that one is mostly
meant for testing and demonstration purposes, otherwise the `*-Broker*` commands
provided by the PowerShell snap-in could be used directly.

## What does it provide?

To interact with CVAD, a `psytricks.wrapper.PSyTricksWrapper` object needs to be
instantiated and passed the address of the *Delivery Controller* to connect to,
for example:

```Python
from psytricks.wrapper import PSyTricksWrapper

wrapper = PSyTricksWrapper(deliverycontroller="cdc01.vdi.example.xy")
```

### Fetching status information

The wrapper object can then be used to e.g. retrieve information on the machines
controlled ("brokered") by Citrix:

```Python
machines = wrapper.get_machine_status()

for machine in machines:
    print(f"[{machine["DNSName"]}] is in power state '{machine["PowerState"]}'")
print(f"Got status details on {len(machines)} machines.")
```

### Performing actions

To restart a machine, use something like this:

```Python
wrapper.perform_poweraction(machine="vm23.vdi.example.xy", action="restart")
```

For placing a machine in *Maintenance Mode* use:

```Python
wrapper.set_maintenance(machine="vm42.vdi.example.xy", disable=False)
```

[www_cvad]: https://docs.citrix.com/en-us/citrix-virtual-apps-desktops
