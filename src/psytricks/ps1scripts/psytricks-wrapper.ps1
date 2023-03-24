[CmdletBinding()]
param (
    # the JSON config file to use
    [Parameter(Mandatory = $true)]
    [string]
    $JsonConfig,

    [Parameter()]
    [string]
    $CommandName = ""
)


try {
    $Config = Get-Content $JsonConfig | ConvertFrom-Json -EA Stop
}
catch {
    throw "Error reading JSON configuration file: [$JsonConfig]"
}

Add-PSSnapin Citrix.Broker.Admin.V2


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
else {
    $Data = Get-ChildItem -Path "C:\Temp" | `
        Select-Object -Property Name, Length, CreationTime
}

$Data | ConvertTo-Json -Compress

# $json = $("asdf ä ö ü fdsa" | ConvertTo-Json -Compress)
# $json
