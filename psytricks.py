"""PowerShell Python Citrix Tricks."""

import subprocess
import json
from os.path import dirname, abspath
from pathlib import Path
import logging
from logging import warning, debug

from pprint import pprint

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

# define the full path to the PowerShell executable:
ps_exe = (
    Path(os.environ["SYSTEMROOT"])
    / "System32"
    / "WindowsPowerShell"
    / "v1.0"
    / "powershell.exe"
)

psscripts = Path(abspath(dirname(__file__))) / "resources" / "powershell"
pswrapper = psscripts / "psytricks-wrapper.ps1"
warning(f"Using PowerShell script [{pswrapper}].")

completed = subprocess.run(["powershell", "-File", pswrapper], capture_output=True)
if completed.stderr:
    raise RuntimeError(f"PowerShell call had issues: {completed.stderr}!")

stdout = completed.stdout.decode(encoding="cp850")
parsed = json.loads(stdout)
pprint(parsed)
