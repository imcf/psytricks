"""Mappings of numerical state values to their human-readable names.

Various objects returned by the Citrix cmdlets contain "state" information,
related to power, registration and others. When these objects are converted to
JSON by PowerShell, the state information that is usually given as strings will
be silently converted into numerical values.

The dicts defined here can be used to map the numerical values back to their
descriptive names. The mapped names are corresponding to the ones described in
the official Citrix CVAD 2203 developer docs (all transformed to lowercase):

https://developer-docs.citrix.com/projects/citrix-virtual-apps-desktops-sdk/en/2203/
"""

#######################################################################################

power_state = {
    0: "unmanaged",
    1: "unknown",
    2: "unavailable",
    3: "off",
    4: "on",
    5: "suspended",
    6: "turningon",
    7: "turningoff",
    8: "suspending",
    9: "resuming",
}
"""A machine's *power status* (`Citrix.Broker.Admin.SDK.PowerState`).

As returned by `Get-BrokerMachine` (used in
`psytricks.wrapper.PSyTricksWrapper.get_machine_status()`).
"""


#######################################################################################

power_action = {
    0: "turnon",
    1: "turnoff",
    2: "shutdown",
    3: "reset",
    4: "restart",
    5: "suspend",
    6: "resume",
}
"""A *power action* (`Citrix.Broker.Admin.SDK.Hostingpoweraction`).

As returned by `New-BrokerHostingPowerAction` (used in
`psytricks.wrapper.PSyTricksWrapper.perform_poweraction()`).
"""


#######################################################################################

registration_state = {
    0: "unregistered",
    1: "initializing",
    2: "registered",
    3: "agenterror",
}
"""A machine's *registration status* (`Citrix.Broker.Admin.SDK.RegistrationState`).

As returned by `Get-BrokerMachine` (used in
`psytricks.wrapper.PSyTricksWrapper.get_machine_status()`).
"""


#######################################################################################

summary_state = {
    0: "off",
    1: "unregistered",
    2: "available",
    3: "disconnected",
    4: "inuse",
    5: "preparing",
}
"""A machine's *status summary* (`Citrix.Broker.Admin.SDK.DesktopSummaryState`).

As returned by:
* `Get-BrokerMachine` as field `SummaryState` (via
  `psytricks.wrapper.PSyTricksWrapper.get_machine_status()`)
* `Get-BrokerSession` as field `MachineSummaryState`(via
  `psytricks.wrapper.PSyTricksWrapper.get_sessions()`)
"""


#######################################################################################


session_state = {
    1: "connected",
    2: "active",
    3: "disconnected",
}
"""A *session status* (`Citrix.Broker.Admin.SDK.SessionState`).

As returned by `Get-BrokerSession` (used in
`psytricks.wrapper.PSyTricksWrapper.get_sessions()`).

**NOTE**: the exact mapping seems to depend on the "*functional level*" of the
machine, in case it is below `L7` the mapping is apparently different (but even
Xen 8.0 VMs are reporting `L7_9`, so this is fairly reasonable). In doubt,
consult the Citrix documentation!
"""

#######################################################################################


by_keyword = {
    "SummaryState": summary_state,
    "MachineSummaryState": summary_state,
    "RegistrationState": registration_state,
    "PowerState": power_state,
    "SessionState": session_state,
    "Action": power_action,
}
"""Combined mapping dict using the *Citrix labels* as keys."""
