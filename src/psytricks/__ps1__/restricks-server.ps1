# Communication with the CVAD / Citrix toolstack requires the corresponding
# snap-in to be loaded, which is only supported on *Windows PowerShell*, not
# on *PowerShell Core* et al, so we strictly need the "Desktop" edition:
#Requires -PSEdition Desktop

[CmdletBinding()]
param (
    [Parameter(
        Mandatory = $true,
        ParameterSetName = "Startup",
        HelpMessage = "The address of the Citrix Delivery Controller."
    )]
    [string]
    $AdminAddress,

    [Parameter(
        ParameterSetName = "Startup",
        HelpMessage = "The port to listen on (default: 8080)."
    )]
    [Parameter(
        ParameterSetName = "Shutdown",
        HelpMessage = "The port to send the shutdown request to (default: 8080)."
    )]
    [int]
    $ListenPort = 8080,

    [Parameter(
        ParameterSetName = "Startup",
        HelpMessage = "A logfile to use for the output (default: stdtout)."
    )]
    [string]
    $LogFile,

    [Parameter(
        ParameterSetName = "Shutdown",
        HelpMessage = "Shut down the listener and terminate the script."
    )]
    [switch]
    $Shutdown
)

$ErrorActionPreference = "Stop"

#region globals

$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $script:MyInvocation.MyCommand.Path

# define color shorthands to be used with "Write-Host" commands:
$Blue = @{ForegroundColor = "Blue" }
$Cyan = @{ForegroundColor = "Cyan" }
$Green = @{ForegroundColor = "Green" }
$Magenta = @{ForegroundColor = "Magenta" }
$Red = @{ForegroundColor = "Red" }
$Yellow = @{ForegroundColor = "Yellow" }

#endregion globals


#region shutdownlogic

<#
This part is required since the HTTPListener loop in the server script is
blocking and therefore not reacting to a SIGTERM / Ctrl+C. To work around this
the shutdown is performed in a multi-step process:

1. A "shutdown-marker" file is created in the TEMP directory of the user running
   the server script to indicate to the server that we're actually requesting it
   to terminate.
2. Next an HTTP request to the "/end" endpoint is sent, which is received by the
   listener and will cause the listener loop to stop. The rest of the server
   script will then check if the shutdown-marker is present and if yes clean up
   and fully terminate. In case the marker file is not present (meaning only the
   HTTP request was sent), the script will re-start the HTTP listener after a
   timeout of 5s.
#>

if ($Shutdown) {
    try {
        # first create the shutdown marker file:
        $StopMarker = Join-Path $env:TEMP "_shutdown_restricks_server_"
        "Terminate" | Out-File $StopMarker

        # now send a shutdown request to the listener with a very short timeout:
        try {
            $null = Invoke-WebRequest "http://localhost:$ListenPort/end" -TimeoutSec 1
        } catch {
            # in case the request timed out this means the listener has been
            # shut down or crashed before, usually resulting in an orphaned
            # "restricks-server.exe" process that needs to be killed explicitly
            # (use 'SilentlyContinue' in case the server was started differently
            # or the WinSW executable has a different name):
            Stop-Process -Name "restricks-server" -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "Issue shutting down: $_"
    } finally {
        exit
    }
}

#endregion shutdownlogic


#region boilerplate

Add-PSSnapIn Citrix.Broker.Admin.V2 -ErrorAction Stop

# locate and dot-source the libs file:
$LibPath = Join-Path $ScriptPath "psytricks-lib.ps1"
if (!(Test-Path $LibPath)) {
    throw "Error loading functions etc. (can't find $LibPath)!"
}
. $LibPath

#endregion boilerplate


#region route-keywords

$GetRoutes = @(
    "DisconnectAll",
    "GetAccessUsers",
    "GetMachineStatus",
    "GetSessions"
)

$PostRoutes = @(
    "DisconnectSession",
    "MachinePowerAction",
    "SendSessionMessage",
    "SetAccessUsers",
    "SetMaintenanceMode"
)

#endregion route-keywords


#region functions

function Format-Date {
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Send-Response {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The HttpListener context response object."
        )]
        $Response,

        [Parameter(HelpMessage = "The HTTP status code to send (default=200).")]
        [int]
        $StatusCode = 200,

        [Parameter(
            HelpMessage = 'The content body ("payload") to return in the ' + `
                'response. For non-HTML responses (which are the default), ' + `
                'this will be placed in the "Data" object. A "Status" ' + `
                'object will be automatically generated from the other ' + `
                'parameters. Needs to be serializable!'
        )]
        $Body = "",

        [Parameter(HelpMessage = "The internal execution status (0 = success).")]
        [string]
        $ExecutionStatus = 0,

        [Parameter(HelpMessage = "An error message for the 'Status' JSON section.")]
        [string]
        $ErrorMesage = "",

        [Parameter(HelpMessage = "Use 'text/html' instead of 'application/json'.")]
        [Switch]
        $Html
    )
    $Type = "application/json"
    if ($Html) {
        $Type = "text/html"
        $Payload = $Body
    } else {
        $Status = @{
            ExecutionStatus  = $ExecutionStatus
            ErrorMessage     = $ErrorMesage
            ScriptName       = $ScriptName
            ScriptPath       = $ScriptPath
            PSyTricksVersion = $Version
            Timestamp        = [int64](Get-Date -UFormat %s)
        }

        $Payload = @{
            "Status" = $Status
            "Data"   = $Body
        } | ConvertTo-Json -Depth 4
    }

    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Payload)  # convert to bytes
    $Response.ContentLength64 = $Buffer.Length
    $Response.ContentType = $Type
    $Response.StatusCode = $StatusCode
    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
    $Response.OutputStream.Close()
    Write-Host "Response sent successfully." @Green

}


function Split-RawUrl {
    param (
        [Parameter()]
        [string]
        $RawUrl
    )
    # check if RawUrl starts with a slash, then strip it:
    if (-not($RawUrl[0] -eq "/")) {
        throw "Invalid 'RawUrl' property: $RawUrl"
    }
    $Parsed = $RawUrl.Split("/")
    Write-Host "Parsed URL ($($Parsed.Length) segments): $Parsed" @Cyan
    return $Parsed
}


function Get-BrokerData {
    param (
        $ParsedUrl
    )
    $Command = $ParsedUrl[1]
    Write-Host "Get-BrokerData($Command)" @Cyan

    $TStart = Get-Date
    switch ($Command) {
        "GetSessions" {
            $Desc = "sessions"
            $BrokerData = Get-Sessions
        }

        "GetMachineStatus" {
            $Desc = "machines"
            $BrokerData = Get-MachineStatus
        }

        "GetAccessUsers" {
            $Desc = "users"
            $Group = $ParsedUrl[2]
            Write-Host "> Group=[$Group]" @Cyan
            $BrokerData = Get-AccessUsers -Group $Group
        }

        # "DisconnectAll" { throw "Not yet implemented!" }

        Default { throw "Invalid: $Command" }
    }
    Write-Host "Got $($BrokerData.Length) $Desc from Citrix." @Cyan
    Write-Host "Took $(($(Get-Date) - $TStart).TotalMilliseconds) ms" @Magenta

    return $BrokerData
}


function Send-BrokerRequest {
    param (
        # the parsed URL as returned by Split-RawUrl
        [Parameter(Mandatory = $True)]
        $ParsedUrl,

        # the JSON payload of the POST request
        [Parameter(Mandatory = $True)]
        $Payload
    )
    $Command = $ParsedUrl[1]
    Write-Host "Send-BrokerRequest($Command)" @Cyan

    $TStart = Get-Date
    switch ($Command) {
        "DisconnectSession" {
            $Desc = "session disconnect"
            $DNSName = $Payload.DNSName
            Write-Host "> DNSName=[$DNSName]" @Cyan
            $BrokerData = Disconnect-Session -DNSName $DNSName
        }

        "MachinePowerAction" {
            $Desc = "power action"
            $DNSName = $Payload.DNSName
            $Action = $Payload.Action
            Write-Host "> DNSName=[$DNSName]" @Cyan
            Write-Host "> Action=[$Action]" @Cyan
            $BrokerData = Invoke-PowerAction -DNSName $DNSName -Action $Action
        }

        "SendSessionMessage" {
            $Desc = "message popup"
            $DNSName = $Payload.DNSName
            $Title = $Payload.Title
            $Text = $Payload.Text
            $MessageStyle = [string]$Payload.MessageStyle
            if ($MessageStyle -eq "") {
                $MessageStyle = "Information"
            }
            Write-Host "> DNSName=[$DNSName]" @Cyan
            Write-Host "> Title=[$Title]" @Cyan
            Write-Host "> Text=[$Text]" @Cyan
            Write-Host "> MessageStyle=[$MessageStyle]" @Cyan
            $BrokerData = Send-SessionMessage `
                -DNSName $DNSName `
                -Title $Title `
                -Text $Text `
                -MessageStyle $MessageStyle
        }

        "SetAccessUsers" {
            $Desc = "group access permission"
            $Group = $Payload.Group
            $UserNames = $Payload.UserNames
            $RemoveAccess = [bool]$Payload.RemoveAccess
            Write-Host "> Group=[$Group]" @Cyan
            Write-Host "> UserNames=[$UserNames]" @Cyan
            Write-Host "> RemoveAccess=[$RemoveAccess]" @Cyan
            $BrokerData = Set-AccessUsers `
                -Group $Group `
                -UserNames $UserNames `
                -RemoveAccess:$RemoveAccess
        }

        "SetMaintenanceMode" {
            $Desc = "maintenance mode"
            $DNSName = $Payload.DNSName
            $Disable = [bool]$Payload.Disable
            Write-Host "> DNSName=[$DNSName]" @Cyan
            Write-Host "> Disable=[$Disable]" @Cyan
            $BrokerData = Set-MaintenanceMode -DNSName $DNSName -Disable:$Disable
        }

        Default { throw "Invalid: $Command" }
    }
    Write-Host "Sent $Desc request to Citrix." @Cyan
    Write-Host "Took $(($(Get-Date) - $TStart).TotalMilliseconds) ms" @Magenta

    return $BrokerData
}


function Switch-GetRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "GET> $($Request.Url)" @Blue
    $ParsedUrl = Split-RawUrl -RawUrl $Request.RawUrl
    $Command = $ParsedUrl[1]

    if ($Command -eq 'end') {
        Send-Response -Response $Response -Body "Terminating."
        Write-Host "Received a termination request, stopping." @Red
        break

    } elseif ($Command -eq '') {
        $html = "<h1>$ScriptName ($Version)</h1><p>Running from: $ScriptPath</p>"
        Send-Response -Response $Response -Body $html -Html

    } elseif ($Command -eq 'version') {
        Send-Response -Response $Response -Body ""

    } elseif ($GetRoutes -contains $Command) {
        try {
            $Body = Get-BrokerData -ParsedUrl $ParsedUrl
        } catch {
            Send-Response -Response $Response -StatusCode 400 -Body $_ -Html
        }
        Send-Response -Response $Response -Body $Body

    } else {
        Send-Response `
            -Response $Response `
            -StatusCode 400 `
            -Html `
            -Body "Invalid or unknown command: [$Command]"
    }
}


function Switch-PostRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "POST> $($Request.Url)" @Blue
    $ParsedUrl = Split-RawUrl -RawUrl $Request.RawUrl
    $Command = $ParsedUrl[1]

    if (-not ($Request.HasEntityBody)) {
        Send-Response -Response $Response -Body "No POST data." -StatusCode 400 -Html

    } elseif ($PostRoutes -contains $Command) {
        try {
            $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
            $Content = $StreamReader.ReadToEnd()
            $Decoded = ConvertFrom-Json $Content
        } catch {
            Send-Response $Response -Body "Decoding error: $_" -StatusCode 422 -Html
            return
        }

        $BrokerData = Send-BrokerRequest -ParsedUrl $ParsedUrl -Payload $Decoded
        Send-Response -Response $Response -Body $BrokerData

    } else {
        Send-Response `
            -Response $Response `
            -StatusCode 400 `
            -Html `
            -Body "Invalid or unknown command: [$Command]"
    }
}


function Start-ListenerBlocking {
    try {
        $Prefix = "http://localhost:$ListenPort/"
        $Listener = [System.Net.HttpListener]::new()
        $Listener.Prefixes.Add($Prefix)
        $Listener.Start()

        if ($Listener.IsListening) {
            Write-Host "[$(Format-Date)] $ScriptName listening: $Prefix" @Yellow
        }

        while ($Listener.IsListening) {
            try {
                # when a request is made GetContext() will return it as an object:
                $Context = $Listener.GetContext()

                $Request = $Context.Request
                $Response = $Context.Response

                if ($Request.HttpMethod -eq 'GET') {
                    Switch-GetRequest -Request $Request
                }

                if ($Request.HttpMethod -eq 'POST') {
                    Switch-PostRequest -Request $Request
                }
            } catch {
                $Message = "ERROR processing request"
                Write-Host "$($Message): $_" @Red
                try {
                    Send-Response `
                        -Response $Response `
                        -StatusCode 400 `
                        -ExecutionStatus 1 `
                        -ErrorMesage $_ `
                        -Body $Message
                } catch {
                    Write-Host "Unable to send the response: $_" @Red
                }
            }
        }

    } catch {
        Write-Host "Unexpected error, terminating: $_" @Red

    } finally {
        if ($Listener.IsListening) {
            Write-Host "Stopping HTTP listener..." @Yellow
            $Listener.Stop()
        }
        Write-Host "[$(Format-Date)] $ScriptName terminated." @Yellow
        Write-Host "----------------------------------------------------" @Blue
    }
}


function Start-ListenerLoop {
    Write-Host "====================================================" @Blue
    Write-Host "Starting: $ScriptPath" @Blue
    Write-Host "PSyTricksVersion: $Version" @Blue
    Write-Host "Citrix 'AdminAddress': $AdminAddress" @Blue
    Write-Host "====================================================" @Blue


    while ($true) {
        Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++++++" @Blue
        Write-Host "PID: [$PID]" @Blue
        Start-ListenerBlocking

        Write-Host "HTTP listener was stopped, checking for shutdown file..." @Yellow
        $StopMarker = Join-Path $env:TEMP "_shutdown_restricks_server_"
        if (Test-Path $StopMarker) {
            Write-Host "Found shutdown file, terminating..." @Yellow
            Remove-Item $StopMarker
            Write-Host "====================================================" @Blue
            Write-Host "[$(Format-Date)] cleaned up, shutdown complete!" @Blue
            Write-Host "====================================================" @Blue
            return
        }
        Write-Host "No shutdown file [$StopMarker] present." @Blue
        Write-Host "Re-starting in 5s, press Ctrl+C to abort..." @Blue
        Start-Sleep -Seconds 5
        Write-Host "Wait-time elapsed, re-starting the listener..."
    }
}

#endregion functions


#region main

if ($LogFile -eq "") {
    # output will not be redirected
    Start-ListenerLoop
} else {
    try {
        [io.file]::OpenWrite($LogFile).close()
    } catch {
        throw "Unable to open log file for writing: [$LogFile]"
    }
    Write-Host "[$ScriptName] logs will go to [$LogFile]."
    # 'Write-Host' is writing to the 'Information' stream (which is #6), so we
    # need to redirect that one to the log file:
    Start-ListenerLoop 6>&1 | Out-File $LogFile -Encoding "utf8"
}

#endregion main
