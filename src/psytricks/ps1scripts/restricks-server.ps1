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

# locate and dot-source the libs file:
$LibPath = Join-Path $ScriptPath "psytricks-lib.ps1"
if (!(Test-Path $LibPath)) {
    throw "Error loading functions etc. (can't find $LibPath)!"
}
. $LibPath

#endregion boilerplate



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

        # the HTTP status code
        [Parameter()]
        [int]
        $StatusCode = 200,

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

    $Json = $BrokerData | ConvertTo-Json -Depth 4
    return $Json
}


function Send-BrokerData {
    param (
        # the parsed URL as returned by Split-RawUrl
        [Parameter(Mandatory = $True)]
        [string[]]
        $ParsedUrl,

        # the JSON payload of the POST request
        [Parameter(Mandatory = $True)]
        $Payload
    )
    $Command = $ParsedUrl[1]
    Write-Host "Send-BrokerData($Command)" @Cyan

    switch ($Command) {
        "DisconnectSession" {
            $DNSName = $Payload.DNSName
            Write-Host "> DNSName=[$DNSName]" @Cyan
            $BrokerData = Disconnect-Session -DNSName $DNSName
        }

        "MachinePowerAction" {
            $BrokerData = Get-MachineStatus
        }

        "SendSessionMessage" {
            $Group = $ParsedUrl[2]
            Write-Host "> Group=[$Group]" @Cyan
            $BrokerData = Get-AccessUsers -Group $Group
        }

        "SetAccessUsers" {
            $Group = $ParsedUrl[2]
            Write-Host "> Group=[$Group]" @Cyan
            $BrokerData = Get-AccessUsers -Group $Group
        }

        "SetMaintenanceMode" {
            $Group = $ParsedUrl[2]
            Write-Host "> Group=[$Group]" @Cyan
            $BrokerData = Get-AccessUsers -Group $Group
        }

        Default { throw "Invalid: $Command" }
    }
    Write-Host "Sent FIXME to Citrix." @Cyan

    $Json = $BrokerData | ConvertTo-Json -Depth 4
    return $Json
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
        Send-Response -Response $Response -Body "Terminating." -Html
        Write-Host "Received a termination request, stopping." @Red
        break

    } elseif ($Command -eq '') {
        $html = "<h1>$ScriptName</h1><p>Running from: $ScriptPath</p>"
        Send-Response -Response $Response -Body $html -Html

    } elseif ($GetRoutes -contains $Command) {
        try {
            $Body = Get-BrokerData -ParsedUrl $ParsedUrl
        } catch {
            Send-Response -Response $Response -StatusCode 400 -Body $_
        }
        Send-Response -Response $Response -Body $Body

    } else {
        Send-Response `
            -Response $Response `
            -StatusCode 400 `
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
        Send-Response -Response $Response -Body "No POST data." -Html
        return

    } elseif ($PostRoutes -contains $Command) {
        $StreamReader = [System.IO.StreamReader]::new($Request.InputStream)
        $Content = $StreamReader.ReadToEnd()

        try {
            $Decoded = ConvertFrom-Json $Content
        } catch {
            Send-Response -Response $Response -Body "Error decoding JSON." -Html
            return
        }

        Send-BrokerData -ParsedUrl $ParsedUrl -Payload $Decoded

        Write-Host $Decoded.foo @Yellow
        # $Decoded.PSObject.Properties | ForEach-Object {
        #     Write-Host $_.Name @Blue
        #     Write-Host $_.Value @Blue
        # }

        $html = "<h1>$ScriptName</h1><p>POST successful!</p>"
        Send-Response -Response $Response -Body $html -Html
    } else {
        Send-Response `
            -Response $Response `
            -StatusCode 400 `
            -Body "Invalid or unknown command: [$Command]"
    }
}


try {
    $Listener = [System.Net.HttpListener]::new()
    $Listener.Prefixes.Add("http://localhost:$ListenPort/")
    $Listener.Start()

    if ($Listener.IsListening) {
        Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++++++" @Blue
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
    Write-Host "----------------------------------------------------" @Blue
}
