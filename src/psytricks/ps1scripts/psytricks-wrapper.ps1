[CmdletBinding()]
param (
    # the JSON config file to use
    [Parameter(Mandatory = $true)]
    [string]
    $JsonConfig,

    # the command defining the action to be performed by the wrapper
    [Parameter(Mandatory = $true)]
    [ValidateSet(
        "DisconnectSession",
        "GetAccessUsers",
        "GetMachineStatus",
        "GetSessions",
        "MachinePowerAction",
        "SendSessionMessage",
        "SetAccessUsers",
        "SetMaintenanceMode"
    )]
    [string]
    $CommandName,

    # machine name to perform a specific action on
    [Parameter()]
    [string]
    $MachineName = "",

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


#region functions

function Get-MachineStatus {
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
    return $Data
}

function Get-Sessions {
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
    return $Data
}

#endregion functions


if ($CommandName -eq "GetMachineStatus") {
    $Data = Get-MachineStatus
} elseif ($CommandName -eq "GetSessions") {
    $Data = Get-Sessions
} elseif ($CommandName -eq "DisconnectSession") {
    if ($MachineName -eq "") {
        throw "Parameter 'MachineName' is missing!"
    }
    Write-Error $MachineName
    # $Data = Disconnect-Session
} else {
    Write-Error "Command not yet implemented: $CommandName"
}

$Data | ConvertTo-Json -Compress
