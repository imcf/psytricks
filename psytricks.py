"""PowerShell Python Citrix Tricks."""

import subprocess
import json
from os.path import dirname, abspath
from pathlib import Path
from logging import warning

psscripts = Path(abspath(dirname(__file__))) / "resources" / "powershell"
pswrapper = psscripts / "psytricks-wrapper.ps1"
warning(f"Using PowerShell script [{pswrapper}].")

completed = subprocess.run(["powershell", "-File", pswrapper], capture_output=True)
if completed.stderr:
    raise RuntimeError(f"PowerShell call had issues: {completed.stderr}!")

stdout = completed.stdout.decode(encoding="cp850")
print(stdout)
