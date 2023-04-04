[CmdletBinding()]
param (
    # the JSON config file to use
    [Parameter(Mandatory = $true)]
    [string]
    $JsonConfig,

    [Parameter()]
    [string]
    $CommandName = "",

    # switch to request dummy data (testing)
    [Parameter()]
    [switch]
    $Dummy
)

<#
TODO: commands to be implemented
- SendSessionMessage (Send-BrokerSessionMessage)
- GetAccessUsers (Get-BrokerAccessPolicyRule)
- SetAccessUsers (Set-BrokerAccessPolicyRule -AddIncludedUsers / -RemoveIncludedUsers)
- MachinePowerAction (New-BrokerHostingPowerAction)
- DisconnectSession (Disconnect-BrokerSession)
- SetMaintenanceMode (Set-BrokerMachineMaintenanceMode)
#>


try {
    $Config = Get-Content $JsonConfig | ConvertFrom-Json -EA Stop
} catch {
    throw "Error reading JSON configuration file: [$JsonConfig]"
}

try {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
} catch {
    # failing to load the snap-in is only acceptable in "dummy" mode:
    if ($Dummy.IsPresent) {
        Write-Verbose "Attempting to return dummy data..."
    } else {
        Write-Error "Error loading Citrix Broker Snap-In!"
        return
    }
}

if ($Dummy.IsPresent) {
    # When being called with the "-Dummy" switch, no actual calls to the Citrix
    # stack will be done, instead simply the contents of a file in a subdir
    # called "dummydata" having the name of the requested command followed by a
    # ".json" suffix will be dumped on stdout.
    # This is intended for very basic testing in an environment where a Citrix
    # stack is not (always) available.
    Get-Content "$PSScriptRoot/dummydata/$CommandName.json"
    return
}


if ($CommandName -eq "GetMachineStatus") {
    $Properties = @(
        "AgentVersion",
        "AssociatedUserUPNs",
        "DesktopGroupName",
        "HostedMachineName",
        "InMaintenanceMode",
        "PowerState",
        "RegistrationState",
        "SessionClientVersion",
        "SessionDeviceId",
        "SessionStartTime",
        "SessionStateChangeTime",
        "SessionUserName",
        "SummaryState"
    )
    $Data = Get-BrokerMachine -AdminAddress $Config.CitrixDC | `
        Select-Object -Property $Properties
} elseif ($CommandName -eq "GetSessions") {
    $Properties = @(
        "DesktopGroupName",
        "DNSName",
        "Protocol",
        "SessionState",
        "SessionStateChangeTime",
        "StartTime",
        "UserName"
    )
    $Data = Get-BrokerSession -AdminAddress $Config.CitrixDC | `
        Select-Object -Property $Properties
} else {
    Write-Error "Unexpected command: $CommandName"
}

$Data | ConvertTo-Json -Compress
