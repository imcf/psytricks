#Requires -PSEdition Desktop

[CmdletBinding()]
param (
    # the delivery controller address to connect to
    [Parameter(Mandatory = $true)]
    [string]
    $AdminAddress,

    # the port to listen on
    [Parameter()]
    [int]
    $ListenPort = 8080
)

$ErrorActionPreference = "Stop"


#region boilerplate

$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $script:MyInvocation.MyCommand.Path

Add-PSSnapIn Citrix.Broker.Admin.V2 -ErrorAction Stop


#endregion boilerplate



$GetRoutes = @(
    "DisconnectAll",
    "GetMachineStatus",
    "GetSessions"
)

$PostRoutes = @(
    "DisconnectSession",
    "GetAccessUsers",
    "MachinePowerAction",
    "SendSessionMessage",
    "SetAccessUsers",
    "SetMaintenanceMode"
)

$Blue = @{ForegroundColor = "Blue" }
$Cyan = @{ForegroundColor = "Cyan" }
$Green = @{ForegroundColor = "Green" }
$Red = @{ForegroundColor = "Red" }
$Yellow = @{ForegroundColor = "Yellow" }


function Send-Response {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The HttpListener context response object."
        )]
        $Response,

        [Parameter(HelpMessage = "The content body to return in the response.")]
        [string]
        $Body = "",

        [Parameter(HelpMessage = "Use 'text/html' instead of 'application/json'.")]
        [Switch]
        $Html
    )
    $Type = "application/json"
    if ($Html) {
        $Type = "text/html"
    }
    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Body)  # convert to bytes
    $Response.ContentLength64 = $Buffer.Length
    $Response.ContentType = $Type
    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
    $Response.OutputStream.Close()
    Write-Host "Response sent successfully." @Green

}


function Confirm-RawUrl {
    param (
        [Parameter()]
        [string]
        $RawUrl
    )
    # check if RawUrl starts with a slash, then strip it:
    if (-not($RawUrl[0] -eq "/")) {
        throw "Invalid 'RawUrl' property: $RawUrl"
    }
    $Url = $RawUrl.Substring(1)
    # Write-Host "Validated URL: $Url" @Cyan
    return $Url
}

function Switch-GetRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "GET> $($Request.Url)" @Blue
    $Url = Confirm-RawUrl $Request.RawUrl

    if ($Url -eq 'end') {
        Send-Response -Response $Response -Body "Terminating." -Html
        Write-Host "Received a termination request, stopping." @Red
        break

    } elseif ($Url -eq '') {
        $html = "<h1>$ScriptName</h1><p>Running from: $ScriptPath</p>"
        Send-Response -Response $Response -Body $html -Html

    } elseif ($GetRoutes -contains $Url ) {
        Write-Host "Identified known request: $Url" @Yellow
        Send-Response -Response $Response -Body "Nothing here yet." -Html

    } elseif ($Url -eq 'sessions') {
        Write-Host "Fetching Citrix sessions..." @Cyan
        $CtrxSessions = Get-BrokerSession -AdminAddress $AdminAddress
        Write-Host "Got $($CtrxSessions.Length) sessions from Citrix." @Cyan

        $json = $CtrxSessions | ConvertTo-Json -Depth 4
        Send-Response -Response $Response -Body $json

    } else {
        Send-Response -Response $Response -Body "Nothing here." -Html
    }
}


function Switch-PostRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "POST> $($Request.Url)" @Blue
    $Url = Confirm-RawUrl $Request.RawUrl

    if (-not ($Request.HasEntityBody)) {
        Send-Response -Response $Response -Body "No POST data." -Html
        return

    } elseif ($PostRoutes -contains $Url ) {
        $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
        $Content = $StreamReader.ReadToEnd()

        try {
            $Decoded = ConvertFrom-Json $Content
        } catch {
            Send-Response -Response $Response -Body "Error decoding JSON." -Html
            return
        }

        Write-Host $Decoded.foo @Yellow
        # $Decoded.PSObject.Properties | ForEach-Object {
        #     Write-Host $_.Name @Blue
        #     Write-Host $_.Value @Blue
        # }

        $html = "<h1>$ScriptName</h1><p>POST successful!</p>"
        Send-Response -Response $Response -Body $html -Html
    }
}


try {
    $Listener = [System.Net.HttpListener]::new()
    $Listener.Prefixes.Add("http://localhost:$ListenPort/")
    $Listener.Start()

    if ($Listener.IsListening) {
        Write-Host "$ScriptName listening: $($Listener.Prefixes)" @Yellow
        Write-Host "Location: $ScriptPath" @Blue
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
                # do NOT include details in the response, only log it to stdout!
                Send-Response -Response $Response -Body "$($Message)!" -Html
            } catch {
                Write-Host "Unable to send the response: $_" @Red
            }
        }
    }

} catch {
    Write-Host "Unexpected error, terminating: $_" @Red

} finally {
    Write-Host "Stopping HTTP listener..." @Yellow
    $Listener.Stop()
    Write-Host "$ScriptName terminated." @Yellow
}
