<#

Collection of functions and other definitions to be sourced by other scripts.

#>

# the version variable will be filled by poetry at build time:
$Version = "UNDEFINED"


#region properties-selectors

$MachineProperties = @(
    "AgentVersion",
    "AssociatedUserUPNs",
    "DesktopGroupName",
    "DNSName",
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
    "ClientAddress",
    "ClientName",
    "ClientPlatform",
    "ClientProductId",
    "ClientVersion",
    "ConnectedViaHostName",
    "DesktopGroupName",
    "DNSName",
    "MachineSummaryState",
    "Protocol",
    "SessionState",
    "SessionStateChangeTime",
    "StartTime",
    "Uid",
    "UserName",
    "UserUPN"
)

#endregion properties-selectors



#region functions

function Get-MachineStatus {
    $Data = Get-BrokerMachine -AdminAddress $AdminAddress | `
        Select-Object -Property $MachineProperties
    return $Data
}

function Get-Sessions {
    $Data = Get-BrokerSession -AdminAddress $AdminAddress | `
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
    $Session = Get-BrokerSession -AdminAddress $AdminAddress -DNSName $DNSName
    if ($null -eq $Session) {
        return $null
    }
    if ($Session.SessionState -eq "Disconnected") {
        Write-Verbose "Session already disconnected, not disconnecting again!"
        return Select-Object -InputObject $Session -Property $SessionProperties
    }
    Disconnect-BrokerSession -AdminAddress $AdminAddress -InputObject $Session

    # wait a bit until the status update is reflected by Citrix:
    Start-Sleep -Seconds 0.7

    $Data = Get-BrokerSession -AdminAddress $AdminAddress -DNSName $DNSName | `
        Select-Object -Property $SessionProperties
    return $Data
}

function Get-AccessUsers {
    param (
        # the name of the Delivery Group to get users with access for
        [Parameter()]
        [string]
        $Group
    )
    $Data = Get-BrokerAccessPolicyRule `
        -AdminAddress $AdminAddress `
        -DesktopGroupName $Group | `
        Select-Object -ExpandProperty IncludedUsers
    return $Data
}

function Set-AccessUsers {
    param (
        # the name of the Delivery Group to set access users for
        [Parameter()]
        [string]
        $Group,

        # switch to request removal of the user(s) access permission
        [Parameter()]
        [switch]
        $RemoveAccess,

        # list of usernames to add / remove access to the given group
        [Parameter()]
        [string[]]
        $UserNames
    )
    $Policy = Get-BrokerAccessPolicyRule `
        -AdminAddress $AdminAddress `
        -DesktopGroupName $Group

    if ($null -eq $Policy) {
        throw "Error fetching permissions for Delivery Group [$Group]!"
    }

    if ($RemoveAccess) {
        $Data = Set-BrokerAccessPolicyRule `
            -AdminAddress $AdminAddress `
            -InputObject $Policy `
            -RemoveIncludedUsers $UserNames `
            -PassThru | `
            Select-Object -ExpandProperty IncludedUsers
    } else {
        $Data = Set-BrokerAccessPolicyRule `
            -AdminAddress $AdminAddress `
            -InputObject $Policy `
            -AddIncludedUsers $UserNames `
            -PassThru | `
            Select-Object -ExpandProperty IncludedUsers
    }
    return $Data
}

function Set-MaintenanceMode {
    param (
        # the FQDN of the machine to modify maintenance mode on
        [Parameter()]
        [string]
        $DNSName,

        # switch to disable maintenance mode on the given machine
        [Parameter()]
        [switch]
        $Disable
    )
    $DesiredMode = (-not $Disable)

    $Machine = Get-BrokerMachine `
        -AdminAddress $AdminAddress `
        -DNSName $DNSName

    if ($null -eq $Machine) {
        throw "Error fetching machine object for [$DNSName]!"
    }

    Set-BrokerMachineMaintenanceMode `
        -AdminAddress $AdminAddress `
        -InputObject $Machine `
        -MaintenanceMode $DesiredMode

    $Data = Get-BrokerMachine `
        -AdminAddress $AdminAddress `
        -DNSName $DNSName | `
        Select-Object -Property $MachineProperties

    return $Data
}

function Invoke-PowerAction {
    param (
        # the FQDN of the machine to perform the power action request on
        [Parameter()]
        [string]
        $DNSName,

        # the power action to perform on a machine
        [Parameter()]
        [ValidateSet(
            "reset",
            "restart",
            "resume",
            "shutdown",
            "suspend",
            "turnoff",
            "turnon"
        )]
        [string]
        $Action
    )
    $Data = New-BrokerHostingPowerAction `
        -AdminAddress $AdminAddress `
        -MachineName $DNSName `
        -Action $Action

    return $Data
}

function Send-SessionMessage {
    param (
        # the FQDN of the machine to the pop-up message to
        [Parameter()]
        [string]
        $DNSName,

        # the message title
        [Parameter()]
        [string]
        $Title,

        # the message body
        [Parameter()]
        [string]
        $Text,

        # the message style
        [Parameter()]
        [ValidateSet(
            "Information",
            "Exclamation",
            "Critical",
            "Question"
        )]
        [string]
        $MessageStyle = "Information"
    )
    $Session = Get-BrokerSession `
        -AdminAddress $AdminAddress `
        -DNSName $DNSName

    if ($null -eq $Session) {
        throw "Error fetching session object for [$DNSName]!"
    }

    Send-BrokerSessionMessage `
        -InputObject $Session `
        -AdminAddress $AdminAddress `
        -MessageStyle $MessageStyle `
        -Title $Title `
        -Text $Text
}

#endregion functions
