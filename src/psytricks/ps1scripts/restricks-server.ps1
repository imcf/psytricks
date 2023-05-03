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


Add-PSSnapIn Citrix.Broker.Admin.V2 -ErrorAction Stop

$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $script:MyInvocation.MyCommand.Path


$GetRoutes = @(
    "/DisconnectAll",
    "/GetMachineStatus",
    "/GetSessions"
)

$PostRoutes = @(
    "/DisconnectSession",
    "/GetAccessUsers",
    "/MachinePowerAction",
    "/SendSessionMessage",
    "/SetAccessUsers",
    "/SetMaintenanceMode"
)

$Blue = @{ForegroundColor = "Blue" }
$Cyan = @{ForegroundColor = "Cyan" }
$Green = @{ForegroundColor = "Green" }
$Red = @{ForegroundColor = "Red" }
$Yellow = @{ForegroundColor = "Yellow" }

function Respond {
    param (
        [Parameter(
            Mandatory = $true,
            HelpMessage = "The HttpListener context response object."
        )]
        $Response,

        [Parameter(HelpMessage = "The content body to return in the response.")]
        [string]
        $Body = "",

        [Parameter(HelpMessage = "The content type, by default 'application/json'.")]
        [string]
        $Type = "application/json"
    )
    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Body)  # convert to bytes
    $Response.ContentLength64 = $Buffer.Length
    $Response.ContentType = $Type
    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
    $Response.OutputStream.Close()
    Write-Host "Response sent successfully." @Green

}

function Switch-GetRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "GET> $($Request.Url)" @Blue
    $RawUrl = $Request.RawUrl

    if ($RawUrl -eq '/end') {
        Respond -Response $Response -Body "Terminating." -Type "text/html"
        Write-Host "Received a termination request, stopping." @Red
        break

    } elseif ($RawUrl -eq '/') {
        $html = "<h1>$ScriptName</h1><p>Running from: $ScriptPath</p>"
        Respond -Response $Response -Body $html -Type "text/html"

    } elseif ($GetRoutes -contains $RawUrl ) {
        Write-Host "Identified known request: $RawUrl" @Yellow
        Respond -Response $Response -Body "Nothing here yet." -Type "text/html"

    } elseif ($RawUrl -eq '/sessions') {
        Write-Host "Fetching Citrix sessions..." @Cyan
        $CtrxSessions = Get-BrokerSession -AdminAddress $AdminAddress
        Write-Host "Got $($CtrxSessions.Length) sessions from Citrix." @Cyan

        $json = $CtrxSessions | ConvertTo-Json -Depth 4
        Respond -Response $Response -Body $json

    } else {
        Respond -Response $Response -Body "Nothing here." -Type "text/html"
    }
}

function Switch-PostRequest {
    param (
        [Parameter()]
        $Request
    )
    Write-Host "POST> $($Request.Url)" @Blue
    $RawUrl = $Request.RawUrl

    if (-not ($Request.HasEntityBody)) {
        Respond -Response $Response -Body "No POST data." -Type "text/html"
        return

    } elseif ($PostRoutes -contains $RawUrl ) {
        $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
        $Content = $StreamReader.ReadToEnd()

        try {
            $Decoded = ConvertFrom-Json $Content
        } catch {
            Respond -Response $Response -Body "Error decoding JSON." -Type "text/html"
            return
        }

        Write-Host $Decoded.foo @Yellow
        # $Decoded.PSObject.Properties | ForEach-Object {
        #     Write-Host $_.Name @Blue
        #     Write-Host $_.Value @Blue
        # }

        $html = "<h1>$ScriptName</h1><p>POST successful!</p>"
        Respond -Response $Response -Body $html -Type "text/html"
    }
}


try {
    $Listener = [System.Net.HttpListener]::new()
    $Listener.Prefixes.Add("http://localhost:$ListenPort/")
    $Listener.Start()

    if ($Listener.IsListening) {
        Write-Host "HTTP server listening via: $($Listener.Prefixes)" @Yellow
    }

    while ($Listener.IsListening) {
        # when a request is made GetContext() will return it as an object:
        $Context = $Listener.GetContext()

        $Request = $Context.Request
        $Response = $Context.Response

        try {
            if ($Request.HttpMethod -eq 'GET') {
                Switch-GetRequest -Request $Request
            }

            if ($Request.HttpMethod -eq 'POST') {
                Switch-PostRequest -Request $Request
            }
        } catch {
            Respond -Response $Response -Body "ERROR: $_" -Type "text/html"
        }

    }

} catch {
    Write-Host "ERROR, terminating: $_" @Red
    # if anything above was raising an exception we should still try to send out
    # a response to gracefully complete the request - otherwise clients (like
    # `Invoke-WebRequest` for example) will sit and wait indefinitely:
    try {
        Respond -Response $Response -Body "$ScriptName terminating..." -Type "text/html"
    } catch {
        Write-Host "Unable to send the response."
    }

} finally {
    $Listener.Stop()
}
