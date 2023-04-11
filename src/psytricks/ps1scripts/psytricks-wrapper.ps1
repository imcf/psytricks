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

    # name of a Delivery Group to perform a specific action on
    [Parameter()]
    [string]
    $Group = "",

    # user account name(s) to add / remove Delivery Group access permissions for
    [Parameter()]
    [string[]]
    $UserNames = "",

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

<# TODO: commands to be implemented
- SendSessionMessage (Send-BrokerSessionMessage)
- MachinePowerAction (New-BrokerHostingPowerAction)
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

if ($NoSnapIn) {
    Write-Debug "NOT loading Citrix Broker Snap-In, can only work on 'dummy' data!"
} else {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
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

function Get-AccessUsers {
    param (
        # the name of the Delivery Group to get users with access for
        [Parameter()]
        [string]
        $Group
    )
    $Data = Get-BrokerAccessPolicyRule `
        -AdminAddress $AdmAddr `
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
        -AdminAddress $AdmAddr `
        -DesktopGroupName $Group
    if ($RemoveAccess) {
        $Data = Set-BrokerAccessPolicyRule `
            -AdminAddress $AdmAddr `
            -InputObject $Policy `
            -RemoveIncludedUsers $UserNames `
            -PassThru | `
            Select-Object -ExpandProperty IncludedUsers
    } else {
        $Data = Set-BrokerAccessPolicyRule `
            -AdminAddress $AdmAddr `
            -InputObject $Policy `
            -AddIncludedUsers $UserNames `
            -PassThru | `
            Select-Object -ExpandProperty IncludedUsers
    }
    return $Data
}

#endregion functions


#region main

# define the default status, will be overridden in case of unexpected results
$Status = @{
    "ExecutionStatus" = "0"
    "ErrorMessage"    = ""
}

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
                    throw "Parameter 'DNSName' is missing!"
                }
                $Data = Disconnect-Session -DNSName $DNSName
            }
            "GetAccessUsers" {
                if ($Group -eq "") {
                    throw "Parameter 'Group' is missing!"
                }
                $Data = Get-AccessUsers -Group $Group
            }
            "MachinePowerAction" {}
            "SendSessionMessage" {}
            "SetAccessUsers" {
                if ($Group -eq "") {
                    throw "Parameter 'Group' is missing!"
                }
                if ($UserNames -eq "") {
                    throw "Parameter 'UserNames' is missing!"
                }
                $Data = Set-AccessUsers `
                    -Group $Group `
                    -UserNames $UserNames `
                    -RemoveAccess:$Disable
            }
            "SetMaintenanceMode" {}

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
} | ConvertTo-Json

#endregion main