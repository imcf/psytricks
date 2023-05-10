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

#region boilerplate

$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $script:MyInvocation.MyCommand.Path
$LibPath = Join-Path $ScriptPath "psytricks-lib.ps1"

if (!(Test-Path $LibPath)) {
    throw "Error loading functions etc. (can't find $LibPath)!"
}

# dot-source the libs file:
. $LibPath

#endregion boilerplate


#region snapin

if ($NoSnapIn) {
    Write-Debug "NOT loading Citrix Broker Snap-In, can only work on 'dummy' data!"
} else {
    Add-PSSnapin Citrix.Broker.Admin.V2 -EA Stop
}

#endregion snapin


#region main

# define the default status, will be overridden in case of unexpected results
$Status = @{
    "ExecutionStatus"  = "0"
    "ErrorMessage"     = ""
    "ScriptName"       = "$ScriptName"
    "ScriptPath"       = "$ScriptPath"
    "PSyTricksVersion" = "$Version"
}
$Data = ""

try {
    if ($Dummy) {
        # When running in "dummy" mode, no actual calls to the Citrix stack will
        # be done, instead simply the contents of a file in a subdir called
        # "sampledata" having the name of the requested command followed by a
        # ".json" suffix will be loaded and returned as payload data.
        # This is intended for very basic testing in an environment where a
        # Citrix stack is not (always) available.
        $LoadFrom = "$PSScriptRoot/sampledata/$CommandName.json"
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
        "ExecutionStatus"  = "1"
        "ErrorMessage"     = "$_"
        "ScriptName"       = "$ScriptName"
        "ScriptPath"       = "$ScriptPath"
        "PSyTricksVersion" = "$Version"
    }
    $Data = ""
}


@{
    "Status" = $Status
    "Data"   = $Data
} | ConvertTo-Json -Depth 4

#endregion main