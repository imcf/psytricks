@echo off

:: enter the script's directory:
cd /d "%~dp0"

:: read settings from a file "settings.txt" in the current directory (see the
:: example file provided with this wrapper and rename it accordingly):
:: - specify "=" as the token delimiter
:: - request tokens 1 and 2 to be read from each line
FOR /f "delims== tokens=1,2" %%G IN (settings.txt) DO SET %%G=%%H

:: start the server (showing the command on the console for debugging)
@echo on
powershell.exe ^
    -NoLogo ^
    -NonInteractive ^
    -NoProfile ^
    -File %PS1SCRIPTS%\restricks-server.ps1 ^
    -AdminAddress %ADMINADDRESS% >> %LOGFILE%