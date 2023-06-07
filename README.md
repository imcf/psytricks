# PSytricks

![PyPI](https://img.shields.io/pypi/v/psytricks)
![PyPI - License](https://img.shields.io/pypi/l/psytricks)
![pdoc](https://img.shields.io/badge/docs-pdoc-brightgreen.svg)
![black](https://img.shields.io/badge/code%20style-black-000000.svg)

`P`ower`S`hell P`y`thon Ci`tri`x Tri`cks` - pun intended.

![logo](https://raw.githubusercontent.com/imcf/psytricks/main/resources/images/logo.png)

This package provides an abstraction layer allowing Python code to interact with
a [Citrix Virtual Apps and Desktops (CVAD)][www_cvad] stack, i.e. to fetch
status information and trigger actions on machines and sessions. Since CVAD only
provides a *PowerShell Snap-In* to do so, a core component written in `Windows
PowerShell` (note: **not** `PowerShell Core` as snap-ins are not supported
there) is required.

PSyTricks ships with two options for the PowerShell layer:

* A wrapper script that is launched as a suprocess from the Python code. It
  doesn't require any further setup beyond the package installation but
  performance, well, slow.
* A (zero-authentication) `REST` (see the note below on this) service providing
  several `GET` and `POST` endpoints to request status information or perform
  actions. Performance is *much* better compared to the wrapper script, but
  obviously this requires the code to be running as a service in an appropriate
  permission context.

NOTE: this `RESTful` claim is actually not entirely true. Or basically not at
all, it would be better called an `HTTP-JSON-RPC-API`. We'll still be using the
term `REST` for it as this is basically what people nowadays think of when they
are coming across this label. Sorry, [Roy T. Fielding][www_rtf].

## 🤯 Are you serious?

Calling PowerShell as a subprocess from within Python? 😳

To convert results to JSON and pass them back, just to parse it again in Python.
Really? 🧐

Or, not sure if that's any better, implementing an HTTP REST API in plain
PowerShell?!? 🫣

### ✅ Yes. We. Are

*And the package name was chosen to reflect this.*

To be very clear: performance of the wrapper script is abysmal, but this is *not
at all* an issue for us. Abysmal, as in: for every wrapped call a full (new)
PowerShell process needs to be instantiated, usually taking something like 1-2
seconds. ⏳

The REST interface provides a much better performance, at the cost of some
additional setup. If you're happy to take on this approach, the package offers a
very smooth ride. 🎢🎡

## 🛠🚧 Installation

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

### Installing the 🐍 package

In case you're planning to use `psytricks` via the subprocess approach
(discouraged but less components to set up), you will have to install the
package itself on the Windows machine having the above mentioned *Snap-In*
installed. For the `REST` approach (recommended) only the PowerShell service
described in the section below has to run on that machine - the Python package
can be installed on any computer that is able to talk to the `REST` service.

For installing `psytricks` please create and activate a `venv`, then run:

```bash
pip install psytricks
```

NOTE: this will also register the `psytricks` CLI tool although that one is
mostly meant for testing and demonstration purposes, otherwise the `*-Broker*`
commands provided by the PowerShell snap-in could be used directly.

### Setting up the REST service

The easiest way for installing the REST service is to use [WinSW (Windows
Service Wrapper)][www_winsw] but you may choose anything you like to launch the
server process like NSSM, Scheduled Tasks 📅, homegrown dark magic 🪄🔮 or
others.

To go with **WinSW** simply download the bundled version provided with each
[PSyTricks release][www_releases]. Just look for the `.zip` asset having `REST`
and `WinSW` in its name.

Unzip the downloaded file to the desired target location, e.g.
`%PROGRAMDATA%\PSyTricks`, then copy / rename `restricks-server.example.xml` to
`restricks-server.xml` and open it in an editor.

Adapt the entries in the `<serviceaccount>` section to match your requirements
and make sure to update the hostname passed via the `-AdminAddress` parameter in
the `<startarguments>` section. It needs to point to your Citrix Delivery
Controller, just in case that's not obvious.

Next step is to install and start the service:

```PowerShell
cd C:\ProgramData\PSyTricks
restricks-server.exe isntall
Start-Service RESTricksServer
```

In case the service doesn't start up, check the Windows Event Log and the `.log`
files created by WinSW in the service directory.

Once the service has started, you can monitor its actions by live-watching the
log file:

```PowerShell
Get-Content -Wait C:\ProgramData\PSyTricks\restricks-server.log
```

Tada! That's it, the service is now ready to take HTTP requests (from
`localhost`)! 🎉

Please be aware that the REST interface doesn't do **any authentication** on
purpose, meaning everything / everyone that can access it will be able to run
all requests! We're using it in combination with an SSH tunnel but essentially
anything that controls who / what can access the service will do the job.

## 🎪 What does it provide?

To interact with CVAD, a wrapper object needs to be
instantiated and instructed how to communicate with the stack.

### Using the REST service - *recommended*

After setting up the REST service as described above and making sure to be able
to connect to it (firewall rules, ssh tunnel, ...), a
`psytricks.wrapper.ResTricksWrapper` object can be used while passing the URL
under which the REST service is reachable, e.g.

```Python
from psytricks.wrapper import ResTricksWrapper

wrapper = ResTricksWrapper(base_url="http://localhost:8080/")
```

### Using the subprocess wrapper - *use with caution*

(This is only recommended for testing or if for some reason you don't want /
can't set up the REST service.)

To create a wrapper object using the subprocess variant, a
`psytricks.wrapper.PSyTricksWrapper` with the address of the *Delivery
Controller* to connect to has to be instantiated, for example:

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
[www_winsw]: https://github.com/winsw/winsw
[www_releases]: https://github.com/imcf/psytricks/releases
[www_rtf]: https://roy.gbiv.com/untangled/2008/rest-apis-must-be-hypertext-driven
