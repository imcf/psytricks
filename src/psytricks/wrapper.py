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

from .decoder import parse_powershell_json


RequestNames = Literal["GetMachineStatus", "GetSessions"]


class PSyTricksWrapper:

    """Wrapper handling PowerShell calls and processing of returned data.

    Raises
    ------
    RuntimeError
        Raised in case the PowerShell call was producing output on `stderr`
        (indicating something went wrong) or returned with a non-zero exit code.
    ValueError
        Raised in case decoding the string produced by the PowerShell call on
        `stdout` could not be decoded using "cp850" (indicating it contains
        characters not supported by "code page 850" like e.g. the Euro currency
        symbol "€") or in case parsing it via `json.loads()` failed.
    """

    pswrapper = (
        Path(abspath(dirname(__file__))) / "ps1scripts" / "psytricks-wrapper.ps1"
    )

    def __init__(self, conffile: str):
        """Constructor for the `PSyTricksWrapper` class.

        Parameters
        ----------
        conffile : str
            The path to a JSON-formatted configuration file required by the
            PowerShell script that will be called by the wrapper.
        """
        # FIXME: this is a hack while implementing the package, remove for production!
        self.add_flags = []
        if platform.startswith("linux"):
            self.ps_exe = Path("/snap/bin/pwsh")
            self.add_flags = ["-Dummy"]
        else:
            self.ps_exe = (
                Path(os.environ["SYSTEMROOT"])
                / "System32"
                / "WindowsPowerShell"
                / "v1.0"
                / "powershell.exe"
            )

        self.conffile = Path(conffile)
        log.debug(f"Using PowerShell script [{self.pswrapper}].")
        log.debug(f"Using configuration file [{self.conffile}].")

    def _fetch_data(self, request: RequestNames) -> list:
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
            command = command + self.add_flags
            log.debug(f"Command for subprocess call: {command}")
            completed = subprocess.run(
                command,
                capture_output=True,
                check=True,
            )
            elapsed = time.time() - tstart
            log.debug(f"[PROFILING] PowerShell call: {elapsed:.3}s.")
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
            tstart = time.time()
            stdout = completed.stdout.decode(encoding="cp850")
            elapsed = time.time() - tstart
            log.debug(f"[PROFILING] Decoding stdout: {elapsed:.5}s.")

            tstart = time.time()
            parsed = json.loads(stdout, object_hook=parse_powershell_json)
            elapsed = time.time() - tstart
            log.debug(f"[PROFILING] Parsing JSON: {elapsed:.5}s.")
        except Exception as ex:
            raise ValueError("Error decoding / parsing output!") from ex

        log.debug(f"Got details on {len(parsed)} machines.")
        return parsed

    def get_machine_status(self, **kwargs) -> list:
        """Call the wrapper with command "GetMachineStatus".

        Returns
        -------
        list(str)
            The parsed JSON.
        """
        return self._fetch_data(request="GetMachineStatus")

    def get_sessions(self, **kwargs) -> list:
        """Call the wrapper with command "GetSessions".

        Returns
        -------
        list(str)
            The parsed JSON.
        """
        return self._fetch_data(request="GetSessions")

    def disconnect_session(self, **kwargs) -> list:
        log.warning(kwargs)
