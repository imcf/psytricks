# 🏗️ ResTricks Service Installation / Upgrade TL;DR ⏩

The commands below can be used to upgrade an existing installation of the
`ResTricksService` - for a *fresh* installation you'd also need to create the
target location and adjust the configuration in `restricks-server.xml`.

```PowerShell
# adjust the version and path variables to your preferences:
$PSyTricksTag = "v2.2.0.a21"
$PSyTricksVersion = "2.2.0a21"
$TargetDir = "C:\ProgramData\PSyTricks"

# this one usually doesn't require changes:
$WinSwVersion = "WinSW.NET461-2.12.0"

$PSyTricksPkg = "psytricks-REST-${PSyTricksVersion}_${WinSwVersion}"
$PSyTricksZip = "${PSyTricksPkg}.zip"
$PSyTricksBaseDl = "https://github.com/imcf/psytricks/releases/download"
$PSyTricksUri = "${PSyTricksBaseDl}/${PSyTricksTag}/${PSyTricksZip}"

Set-Location "C:\Temp\"

Invoke-WebRequest -Uri $PSyTricksUri -OutFile $PSyTricksZip
Expand-Archive $PSyTricksZip -DestinationPath .
Set-Location $PSyTricksPkg
# when upgrading, simply remove the example config - for an initial installation
# move it to the target location and rename it to "restricks-server.xml":
Remove-Item restricks-server.example.xml

Stop-Service RESTricksServer
Get-Service RESTricksServer

foreach ($File in Get-ChildItem -File) {
    Unblock-File -Path $File.FullName
    Move-Item -Path $File.FullName -Destination $TargetDir -Force
}

Start-Service RESTricksServer
Get-Service RESTricksServer
Get-Content -Tail 10 "${TargetDir}\restricks-server.wrapper.log"
```
