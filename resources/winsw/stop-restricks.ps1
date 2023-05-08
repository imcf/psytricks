# send a shutdown request to the service with a very short timeout - in case it
# doesn't react this usually means it has been shut down already before, most
# likely resulting in an orphaned "restricks-server.exe" process hanging around
# that needs to be killed explicitly:
try {
    $null = Invoke-WebRequest "http://localhost:8080/end" -TimeoutSec 1
} catch {
    Stop-Process -Name "restricks-server" -ErrorAction SilentlyContinue
}

