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

    # machine name (FQDN) to perform a specific action on
    [Parameter()]
    [string]
    $DNSName = "",

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


#region properties-selectors

$MachineProperties = @(
    "AgentVersion",
    "AssociatedUserUPNs",
    "DesktopGroupName",
    "HostedDNSName",
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

$SessionProperties = @(
    "DesktopGroupName",
    "DNSName",
    "MachineSummaryState",
    "Protocol",
    "SessionState",
    "SessionStateChangeTime",
    "StartTime",
    "UserName",
    "UserUPN"
)

#endregion properties-selectors


try {
    $Config = Get-Content $JsonConfig | ConvertFrom-Json -EA Stop
} catch {
    throw "Error reading JSON configuration file: [$JsonConfig]"
}
$AdmAddr = $Config.CitrixDC

try {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
} catch {
    # failing to load the snap-in is only acceptable in "dummy" mode:
    if ($Dummy.IsPresent) {
        Write-Verbose "Attempting to return dummy data..."
    } else {
        Write-Error "Error loading Citrix Broker Snap-In, continuing in 'Dummy' mode!"
    }
}


#region functions

function Get-MachineStatus {
    $Data = Get-BrokerMachine -AdminAddress $AdmAddr | `
        Select-Object -Property $MachineProperties
    return $Data
}

function Get-Sessions {
    $Data = Get-BrokerSession -AdminAddress $AdmAddr | `
        Select-Object -Property $SessionProperties
    return $Data
}

function Disconnect-Session {
    param (
        # the FQDN of the machine to disconnect the session on
        [Parameter()]
        [string]
        $DNSName
    )
    $Session = Get-BrokerSession -AdminAddress $AdmAddr -DNSName $DNSName
    if ($null -eq $Session) {
        return $null
    }
    if ($Session.SessionState -eq "Disconnected") {
        Write-Verbose "Session already disconnected, not disconnecting again!"
        return Select-Object -InputObject $Session -Property $SessionProperties
    }
    Disconnect-BrokerSession -AdminAddress $AdmAddr -InputObject $Session

    # wait a bit until the status update is reflected by Citrix:
    Start-Sleep -Seconds 0.7

    $Data = Get-BrokerSession -AdminAddress $AdmAddr -DNSName $DNSName | `
        Select-Object -Property $SessionProperties
    return $Data
}

#endregion functions


#region main

# define the default status, will be overridden in case of unexpected results
$Status = @{
    "ExecutionStatus" = "0"
    "ErrorMessage"    = ""
}

if ($Dummy.IsPresent) {
    # When being called with the "-Dummy" switch, no actual calls to the Citrix
    # stack will be done, instead simply the contents of a file in a subdir
    # called "dummydata" having the name of the requested command followed by a
    # ".json" suffix will be loaded and returned as payload data.
    # This is intended for very basic testing in an environment where a Citrix
    # stack is not (always) available.
    $Data = Get-Content "$PSScriptRoot/dummydata/$CommandName.json" | ConvertFrom-Json
} else {
    switch ($CommandName) {
        "GetMachineStatus" { $Data = Get-MachineStatus }
        "GetSessions" { $Data = Get-Sessions }
        "DisconnectSession" {
            if ($DNSName -eq "") {
                throw "Parameter 'DNSName' is missing!"
            }
            $Data = Disconnect-Session -DNSName $DNSName
        }
        "GetAccessUsers" {}
        "MachinePowerAction" {}
        "SendSessionMessage" {}
        "SetAccessUsers" {}
        "SetMaintenanceMode" {}

        # this should never be reached as $CommandName is backed by ValidateSet
        # above, but it's good practice to have a default case nevertheless:
        Default { throw "Unknown command: $CommandName" }
    }
}


@{
    "Status" = $Status
    "Data"   = $Data
} | ConvertTo-Json

#endregion main