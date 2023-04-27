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

# Citrix.Broker.Admin.SDK.PowerState (e.g. used by `Get-BrokerMachine`)
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

# Citrix.Broker.Admin.Sdk.Hostingpoweraction (e.g. by `New-BrokerHostingPowerAction`)
power_action = {
    0: "turnon",
    1: "turnoff",
    2: "shutdown",
    3: "reset",
    4: "restart",
    5: "suspend",
    6: "resume",
}


# Citrix.Broker.Admin.SDK.RegistrationState (e.g. used by `Get-BrokerMachine`)
registration_state = {
    0: "unregistered",
    1: "initializing",
    2: "registered",
    3: "agenterror",
}


# Citrix.Broker.Admin.SDK.DesktopSummaryState (e.g. used by `Get-BrokerMachine`
# as "SummaryState" and by `Get-BrokerSession` as "MachineSummaryState")
summary_state = {
    0: "off",
    1: "unregistered",
    2: "available",
    3: "disconnected",
    4: "inuse",
    5: "preparing",
}

# Citrix.Broker.Admin.SDK.SessionState (e.g. used by `Get-BrokerSession`)
# NOTE: this seems to depend on the "functional level" of the machine, in case
# it is below "L7" the mapping apparently different (but even Xen 8.0 VMs are
# reporting "L7_9", so this is fairly reasonable)!
session_state = {
    1: "connected",
    2: "active",
    3: "disconnected",
}


by_keyword = {
    "SummaryState": summary_state,
    "MachineSummaryState": summary_state,
    "RegistrationState": registration_state,
    "PowerState": power_state,
    "SessionState": session_state,
    "Action": power_action,
}
