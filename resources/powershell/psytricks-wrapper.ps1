Get-ChildItem -Path "C:\Temp" | `
    Select-Object -Property Name,Length,CreationTime | `
    ConvertTo-Json -Compress

# $json = $("asdf ä ö ü fdsa" | ConvertTo-Json -Compress)
# $json
