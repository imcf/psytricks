<#

Stop script to terminate a running RESTricks Server.

This is required since the HTTPListener loop in the server script is blocking
and therefore not reacting to a SIGTERM / Ctrl+C. To work around this the
shutdown is performed in a multi-step process:

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

# first create the shutdown marker file:
$StopMarker = Join-Path $env:TEMP "_shutdown_restricks_server_"
"Terminate" | Out-File $StopMarker

# now send a shutdown request to the listener with a very short timeout:
try {
    $null = Invoke-WebRequest "http://localhost:8080/end" -TimeoutSec 1
} catch {
    # in case the request timed out this means the listener has been shut down
    # (or crashed) already before, usually resulting in an orphaned
    # "restricks-server.exe" process that needs to be killed explicitly:
    Stop-Process -Name "restricks-server" -ErrorAction SilentlyContinue
}
