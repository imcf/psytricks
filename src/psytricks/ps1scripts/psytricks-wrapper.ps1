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


try {
    $Config = Get-Content $JsonConfig | ConvertFrom-Json -EA Stop
}
catch {
    throw "Error reading JSON configuration file: [$JsonConfig]"
}

try {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
}
catch {
    if ($Dummy.IsPresent) {
        Write-Verbose "Attempting to return dummy data..."
    }
    else {
        Write-Error "Error loading Citrix Broker Snap-In!"
        return
    }
}

if ($Dummy.IsPresent) {
    Get-Content "$PSScriptRoot/dummydata/$CommandName.json"
    return
}


if ($CommandName -eq "GetMachineStatus") {
    $Properties = @(
        "HostedMachineName",
        "PowerState",
        "InMaintenanceMode",
        "SummaryState",
        "RegistrationState",
        "SessionUserName",
        "AssociatedUserUPNs",
        "AgentVersion",
        "SessionClientVersion",
        "SessionDeviceId",
        "SessionStartTime",
        "SessionStateChangeTime"
    )
    $Data = Get-BrokerMachine -AdminAddress $Config.CitrixDC | `
        Select-Object -Property $Properties
}
elseif ($CommandName -eq "GetSessions") {
    $Properties = @(
        "UserName",
        "CatalogName",
        "DNSName",
        "Protocol",
        "StartTime",
        "SessionState",
        "SessionStateChangeTime"
    )
    $Data = Get-BrokerSession -AdminAddress $Config.CitrixDC | `
        Select-Object -Property $Properties
}
else {
    Write-Error "Unexpected command: $CommandName"
}

$Data | ConvertTo-Json -Compress
