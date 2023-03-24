"""PowerShell Python Citrix Tricks."""

import subprocess
import json
import os
import time
from os.path import dirname, abspath
from pathlib import Path
import logging
from logging import warning, info, debug
from typing import Literal

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

# TODO: make this configurable!
conffile = Path("config.json")
debug(f"Using configuration file [{conffile}].")


RequestNames = Literal["GetMachineStatus", "Dummy"]


def get_citrix_details(request: RequestNames) -> list:
    """Call the PowerShell wrapper to retrieve information from Citrix.

    Parameters
    ----------
    request : RequestNames
        The name of the request.
    """
    try:
        tstart = time.time()
        command = [
            ps_exe,
            "-NonInteractive",
            "-NoProfile",
            "-File",
            pswrapper,
            "-JsonConfig",
            conffile,
            "-CommandName",
            request,
        ]
        debug(f"Command for subprocess call: {command}")
        completed = subprocess.run(
            command,
            capture_output=True,
            check=True,
        )
        elapsed = time.time() - tstart
        debug(f"PowerShell call took {elapsed:.3}s.")
        if completed.stderr:
            raise RuntimeError(
                "Wrapper returned data on STDERR, this is not expected:\n============\n"
                f"{completed.stderr}\n============\n"
            )
    except subprocess.CalledProcessError as ex:
        raise RuntimeError(
            f"Call returned a non-zero state: {ex.returncode} {ex.stderr}"
        ) from ex

    try:
        stdout = completed.stdout.decode(encoding="cp850")
        parsed = json.loads(stdout)
    except Exception as ex:
        raise RuntimeError("Error decoding / parsing output!") from ex

    return parsed


details = get_citrix_details(request="GetMachineStatus")
info(f"Got details on {len(details)} machines.")
# pprint(details)
