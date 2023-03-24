"""PowerShell Python Citrix Tricks."""

import subprocess
import json
import os
import time

from os.path import dirname, abspath
from pathlib import Path
from typing import Literal
from sys import platform

from loguru import logger as log


RequestNames = Literal["GetMachineStatus", "Dummy"]


class PSyTricksWrapper:

    pswrapper = (
        Path(abspath(dirname(__file__))) / "ps1scripts" / "psytricks-wrapper.ps1"
    )

    def __init__(self, conffile):
        if platform.startswith("linux"):
            self.ps_exe = Path("/snap/bin/pwsh")
        else:
            self.ps_exe = (
                Path(os.environ["SYSTEMROOT"])
                / "System32"
                / "WindowsPowerShell"
                / "v1.0"
                / "powershell.exe"
            )

        self.conffile = Path(conffile)
        log.info(f"Using PowerShell script [{self.pswrapper}].")
        log.debug(f"Using configuration file [{self.conffile}].")

    def get_citrix_details(self, request: RequestNames) -> list:
        """Call the PowerShell wrapper to retrieve information from Citrix.

        Parameters
        ----------
        request : RequestNames
            The name of the request.

        Returns
        -------
        list(str)
            The JSON parsed from the output returned by the PS1 wrapper script.
        """
        try:
            tstart = time.time()
            command = [
                self.ps_exe,
                "-NonInteractive",
                "-NoProfile",
                "-File",
                self.pswrapper,
                "-JsonConfig",
                self.conffile,
                "-CommandName",
                request,
            ]
            log.debug(f"Command for subprocess call: {command}")
            completed = subprocess.run(
                command,
                capture_output=True,
                check=True,
            )
            elapsed = time.time() - tstart
            log.debug(f"PowerShell call took {elapsed:.3}s.")
            if completed.stderr:
                raise RuntimeError(
                    "Wrapper returned data on STDERR, this is not expected:"
                    f"\n============\n{completed.stderr}\n============\n"
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

        log.debug(f"Got details on {len(parsed)} machines.")
        return parsed
