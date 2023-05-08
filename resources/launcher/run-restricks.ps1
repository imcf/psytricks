$ScriptPath = Split-Path $script:MyInvocation.MyCommand.Path
$ScriptName = Split-Path -Leaf $script:MyInvocation.MyCommand.Path


if (($null -eq $env:LOGFILE) -or
    ($null -eq $env:ADMINADDRESS) -or
    ($null -eq $env:PS1SCRIPTS)) {
    throw "Environment variables 'LOGFILE', 'PS1SCRIPTS', 'ADMINADDRESS' are required!"
}

& {
    $PS1Scripts = $env:PS1SCRIPTS
    $Logfile = $env:LOGFILE
    $AdminAddress = $env:ADMINADDRESS
    Write-Output "PS1Scripts: $PS1Scripts"
    Write-Output "Logfile: $Logfile"
    Write-Output "AdminAddress: $AdminAddress"
    $ServerScript = Join-Path $PS1Scripts "restricks-server.ps1"
    # & $ServerScript -AdminAddress $AdminAddress
    $null = Start-Process `
        -Wait `
        -FilePath powershell.exe `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $Logfile `
        -ArgumentList @(
        $ServerScript,
        "-AdminAddress",
        $AdminAddress
    )
} >> $env:LOGFILE