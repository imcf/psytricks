[CmdletBinding()]
param (
    # the delivery controller address to connect to
    [Parameter(Mandatory = $true)]
    [string]
    $AdminAddress,

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

    # name of a Delivery Group to perform a specific action on
    [Parameter()]
    [string]
    $Group = "",

    # user account name(s) to add / remove Delivery Group access permissions for
    [Parameter()]
    [string[]]
    $UserNames = $null,

    # the style of a message to be sent to a session (optional)
    [Parameter()]
    [ValidateSet(
        "Information",
        "Exclamation",
        "Critical",
        "Question"
    )]
    [string]
    $MessageStyle = "Information",

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
    $Action = "",

    # the title of a message to be sent to a session
    [Parameter()]
    [string]
    $Title,

    # the body of a message to be sent to a session
    [Parameter()]
    [string]
    $Text,

    # switch to request removal / disabling of a permission / mode, e.g. used
    # for SetAccessUsers and SetMaintenanceMode
    [Parameter()]
    [switch]
    $Disable,

    # switch to prevent the Citrix snap-in being loaded (only useful for testing)
    [Parameter()]
    [switch]
    $NoSnapIn,

    # switch to request dummy data (testing)
    [Parameter()]
    [switch]
    $Dummy
)


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


#region snapin

if ($NoSnapIn) {
    Write-Debug "NOT loading Citrix Broker Snap-In, can only work on 'dummy' data!"
} else {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
}

#endregion snapin


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


#region main

# define the default status, will be overridden in case of unexpected results
$Status = @{
    "ExecutionStatus" = "0"
    "ErrorMessage"    = ""
}
$Data = ""

try {
    if ($Dummy) {
        # When running in "dummy" mode, no actual calls to the Citrix stack will
        # be done, instead simply the contents of a file in a subdir called
        # "dummydata" having the name of the requested command followed by a
        # ".json" suffix will be loaded and returned as payload data.
        # This is intended for very basic testing in an environment where a
        # Citrix stack is not (always) available.
        $LoadFrom = "$PSScriptRoot/dummydata/$CommandName.json"
        Write-Verbose "Loading dummy data from [$LoadFrom]..."
        $Data = Get-Content $LoadFrom | ConvertFrom-Json
    } else {
        switch ($CommandName) {
            "GetMachineStatus" { $Data = Get-MachineStatus }

            "GetSessions" { $Data = Get-Sessions }

            "DisconnectSession" {
                if ($DNSName -eq "") {
                    throw "Parameter [DNSName] is missing!"
                }
                $Data = Disconnect-Session -DNSName $DNSName
            }

            "GetAccessUsers" {
                if ($Group -eq "") {
                    throw "Parameter [Group] is missing!"
                }
                $Data = Get-AccessUsers -Group $Group
            }

            "MachinePowerAction" {
                if ($DNSName -eq "") {
                    throw "Parameter [DNSName] is missing!"
                }
                if ($Action -eq "") {
                    throw "Parameter [Action] is missing!"
                }
                $Data = Invoke-PowerAction `
                    -DNSName $DNSName `
                    -Action $Action
            }

            "SendSessionMessage" {
                if ($DNSName -eq "") {
                    throw "Parameter [DNSName] is missing!"
                }
                if ($Title -eq "") {
                    throw "Parameter [Title] is missing!"
                }
                if ($Text -eq "") {
                    throw "Parameter [Text] is missing!"
                }
                Send-SessionMessage `
                    -DNSName $DNSName `
                    -Title $Title `
                    -Text $Text `
                    -MessageStyle $MessageStyle
            }

            "SetAccessUsers" {
                if ($Group -eq "") {
                    throw "Parameter [Group] is missing!"
                }
                if (($UserNames.Length -eq 0) -or ($UserNames -eq "") ) {
                    throw "Parameter [UserNames] is missing!"
                }
                $Data = Set-AccessUsers `
                    -Group $Group `
                    -UserNames $UserNames `
                    -RemoveAccess:$Disable
            }

            "SetMaintenanceMode" {
                if ($DNSName -eq "") {
                    throw "Parameter [DNSName] is missing!"
                }
                $Data = Set-MaintenanceMode `
                    -DNSName $DNSName `
                    -Disable:$Disable
            }

            # this should never be reached as $CommandName is backed by ValidateSet
            # above, but it's good practice to have a default case nevertheless:
            Default { throw "Unknown command: $CommandName" }
        }
    }
} catch {
    $Status = @{
        "ExecutionStatus" = "1"
        "ErrorMessage"    = "$_"
    }
    $Data = ""
}


@{
    "Status" = $Status
    "Data"   = $Data
} | ConvertTo-Json -Depth 4

#endregion main