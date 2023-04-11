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

    def _run_ps1_script(self, request: RequestNames, extra_params: list = None) -> list:
        """Call the PowerShell wrapper to retrieve information from Citrix.

        Parameters
        ----------
        request : RequestNames
            The name of the request.

        Returns
        -------
        list(str)
            The "Data" section of the JSON parsed from the output returned by
            the PS1 wrapper script.
        """
        if extra_params is None:
            extra_params = []
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
            command = command + self.add_flags + extra_params
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

        if "Status" not in parsed or "Data" not in parsed:
            raise ValueError(f"Received malformed JSON from PS1 script: {parsed}")

        data = parsed["Data"]
        status = parsed["Status"]

        exec_status = int(status["ExecutionStatus"])
        if exec_status > 0:
            msg = (
                f"JSON returned by the PS1 wrapper contains execution status "
                f"{exec_status} for command [{request}]:\n--------\n"
                f"{status['ErrorMessage']}\n--------\n"
                "This indicates something went wrong talking to the Citrix toolstack."
            )
            log.error(msg)
            raise RuntimeError(msg)

        log.debug(f"Parsed 'Data' section contains {len(data)} items.")
        return data

    def get_machine_status(self, **kwargs) -> list:
        """Call the wrapper with command "GetMachineStatus".

        Returns
        -------
        list(str)
            The parsed JSON.
        """
        return self._run_ps1_script(request="GetMachineStatus")

    def get_sessions(self, **kwargs) -> list:
        """Call the wrapper with command "GetSessions".

        Returns
        -------
        list(str)
            The parsed JSON.
        """
        return self._run_ps1_script(request="GetSessions")

    def disconnect_session(self, **kwargs) -> list:
        """Call the wrapper with command "DisconnectSession".


        Parameters
        ----------
        machine : str
            The FQDN of the machine to disconnect the session on.

        Returns
        -------
        list(str)
            The parsed JSON as returned by the wrapper script.
        """
        return self._run_ps1_script(
            request="DisconnectSession",
            extra_params=["-DNSName", kwargs["machine"]],
        )
