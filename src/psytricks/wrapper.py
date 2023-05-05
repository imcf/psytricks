"""PowerShell Python Citrix Tricks."""

import subprocess
import json
import os
import time

from os.path import dirname, abspath
from pathlib import Path
from typing import Literal
from sys import platform

import requests
from loguru import logger as log

from .decoder import parse_powershell_json


RequestNames = Literal[
    "DisconnectSession",
    "GetAccessUsers",
    "GetMachineStatus",
    "GetSessions",
    "MachinePowerAction",
    "SendSessionMessage",
    "SetAccessUsers",
    "SetMaintenanceMode",
]


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

    def __init__(self, deliverycontroller: str):
        """Constructor for the `PSyTricksWrapper` class.

        Parameters
        ----------
        deliverycontroller : str
            The address (IP or FQDN) of the Citrix Delivery Controller to
            connect to.
        """
        # FIXME: this is a hack while implementing the package, remove for production!
        self.add_flags = []
        if platform.startswith("linux"):
            self.ps_exe = Path("/snap/bin/pwsh")
            self.add_flags = ["-Dummy", "-NoSnapIn"]
        else:
            self.ps_exe = (
                Path(os.environ["SYSTEMROOT"])
                / "System32"
                / "WindowsPowerShell"
                / "v1.0"
                / "powershell.exe"
            )

        self.deliverycontroller = deliverycontroller
        log.debug(f"Using PowerShell script [{self.pswrapper}].")
        log.debug(f"Using Delivery Controller [{self.deliverycontroller}].")

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

        Raises
        ------
        RuntimeError
            Raised in case the PS1 wrapper script pushed anything to STDERR or
            the Python `subprocess` call returned a non-zero exit code or a
            non-zero return code was passed on in the parsed JSON (indicating
            something went wrong on the lowest level when interacting with the
            Citrix toolstack).
        ValueError
            Raised in case parsing the JSON returned by the PS1 wrapper failed
            or it doesn't conform to the expected format (e.g. missing the
            `Data` or `Status` items).
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
                "-AdminAddress",
                self.deliverycontroller,
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
            raise ValueError(f"Error decoding / parsing output:\n{stdout}") from ex

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
        log.trace(f"extra kwargs: {kwargs}")
        return self._run_ps1_script(request="GetMachineStatus")

    def get_sessions(self, **kwargs) -> list:
        """Call the wrapper with command "GetSessions".

        Returns
        -------
        list(str)
            The parsed JSON.
        """
        log.trace(f"extra kwargs: {kwargs}")
        return self._run_ps1_script(request="GetSessions")

    def disconnect_session(self, machine: str, **kwargs) -> list:
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
        log.trace(f"extra kwargs: {kwargs}")
        return self._run_ps1_script(
            request="DisconnectSession",
            extra_params=["-DNSName", machine],
        )

    def get_access_users(self, group: str, **kwargs) -> list:
        """Call the wrapper with command "GetAccessUsers".

        Parameters
        ----------
        group : str
            The name of the Delivery Group to request users having access.

        Returns
        -------
        list(str)
            The parsed JSON as returned by the wrapper script.
        """
        log.trace(f"extra kwargs: {kwargs}")
        return self._run_ps1_script(
            request="GetAccessUsers",
            extra_params=["-Group", group],
        )

    def set_access_users(self, group: str, users: str, disable: bool, **kwargs) -> list:
        """Call the wrapper with command "SetAccessUsers".

        Parameters
        ----------
        group : str
            The name of the Delivery Group to request users having access.
        users : str
            A string with one or more (comma-separated) usernames whose access
            permissions to the given group should be adapted.
        disable : bool
            A flag requesting the permissions for the given username(s) to be
            removed (if True) instead of being added (if False).

        Returns
        -------
        list(str)
            The parsed JSON as returned by the wrapper script.
        """
        log.trace(f"extra kwargs: {kwargs}")
        extra_params = [
            "-Group",
            group,
            "-UserNames",
            users,
        ]
        if disable:
            extra_params.append("-Disable")

        return self._run_ps1_script(request="SetAccessUsers", extra_params=extra_params)

    def set_maintenance(self, machine: str, disable: bool, **kwargs) -> list:
        """Call the wrapper with command "SetMaintenanceMode".

        Parameters
        ----------
        machine : str
            The FQDN of the machine to modify maintenance mode on.
        disable : bool
            A flag requesting maintenance mode for the given machine(s) to be
            turned off (if True) instead of being turned on (if False).

        Returns
        -------
        list(str)
            The parsed JSON as returned by the wrapper script.
        """
        log.trace(f"extra kwargs: {kwargs}")
        extra_params = ["-DNSName", machine]
        if disable:
            extra_params.append("-Disable")

        return self._run_ps1_script(
            request="SetMaintenanceMode", extra_params=extra_params
        )

    def send_message(self, machine: str, message: str, **kwargs) -> None:
        """Call the wrapper with command "SendSessionMessage".

        Parameters
        ----------
        machine : str
            The FQDN of the machine to disconnect the session on.
        message : str
            The path to a JSON file containing the message details (style,
            title, body).
        """
        log.trace(f"extra kwargs: {kwargs}")
        with open(message, "r", encoding="utf-8") as fh:
            msgdata = json.load(fh)

        extra_params = [
            "-DNSName",
            machine,
            "-Title",
            msgdata["title"],
            "-Text",
            "\n".join(msgdata["body"]),  # body is a list of strings, so join it
            "-MessageStyle",
            msgdata["style"],
        ]

        self._run_ps1_script(request="SendSessionMessage", extra_params=extra_params)

    def perform_poweraction(self, machine: str, action: str, **kwargs) -> None:
        """Call the wrapper with command "MachinePowerAction".

        Parameters
        ----------
        machine : str
            The FQDN of the machine to disconnect the session on.
        action : str
            The power action to perform on a machine. Valid choices are `reset`,
            `restart`, `resume`, `shutdown`, `suspend`, `turnoff`, `turnon`.
        """
        log.trace(f"extra kwargs: {kwargs}")
        extra_params = ["-DNSName", machine, "-Action", action]
        return self._run_ps1_script(
            request="MachinePowerAction", extra_params=extra_params
        )


class ResTricksWrapper:

    """Wrapper performing REST requests and processing the responses."""

    def __init__(self, base_url: str = "http://localhost:8080/"):
        """Constructor for the `ResTricksWrapper` class.

        Parameters
        ----------
        base_url : str, optional
            The base URL where to find the ResTricks service, by default
            `http://localhost:8080/`.
        """
        self.base_url = base_url
        self.timeout = 5
        log.debug(f"Initialized {self.__class__.__name__}({base_url})")

    def send_get_request(self, raw_url: str) -> list:
        """Common method for performing a GET request and process the response.

        Parameters
        ----------
        raw_url : str
            The part of the URL that will be appended to `self.base_url`.

        Returns
        -------
        list(str)
            The parsed `JSON` of the response. Will be an empty list in case
            something went wrong performing the GET request or processing the
            response.
        """
        try:
            response = requests.get(self.base_url + raw_url, timeout=self.timeout)
        except Exception as ex:  # pylint: disable-msg=broad-except
            log.error(f"GET request [{raw_url}] failed: {ex}")
            return []

        try:
            data = response.json()
        except Exception as ex:  # pylint: disable-msg=broad-except
            log.error(f"GET request [{raw_url}] didn't return any JSON: {ex}")
            return []

        return data

    def send_post_request(
        self, raw_url: str, payload: dict, no_json: bool = False
    ) -> list:
        """Common method for performing a POST request and process the response.

        Parameters
        ----------
        raw_url : str
            The part of the URL that will be appended to `self.base_url`.
        payload : dict
            The parameters to pass as `JSON` payload to the POST request.
        no_json : bool
            If set to `True` the response is expected to contain no `JSON` and
            an empty list will be returned.

        Returns
        -------
        list(str)
            The parsed `JSON` of the response. Will be an empty list in case
            something went wrong performing the POST request or processing the
            response (or in case the `no_json` parameter was set to `True`).
        """
        try:
            response = requests.post(
                self.base_url + raw_url, json=payload, timeout=self.timeout
            )
        except Exception as ex:  # pylint: disable-msg=broad-except
            log.error(f"POST request [{raw_url}] failed: {ex}")
            return []

        if no_json:
            log.debug(f"No-payload response status code: {response.status_code}")
            return []

        return response.json()

    def get_machine_status(self) -> list:
        """Send a GET request with "GetMachineStatus".

        Returns
        -------
        list(str)
            The `JSON` returned by the REST service.
        """
        return self.send_get_request("GetMachineStatus")

    def get_sessions(self) -> list:
        """Send a GET request with "GetSessions".

        Returns
        -------
        list(str)
            The `JSON` returned by the REST service.
        """
        return self.send_get_request("GetSessions")

    def send_message(self, machine: str, message: str, title: str, style: str):
        """Send a POST request with "SendSessionMessage".

        Parameters
        ----------
        machine : str
            The FQDN of the machine to disconnect the session on.
        message : str
            The message body.
        title : str
            The message title.
        style : str
            The message style defining the icon shown in the pop-up message.
            One of ["Information", "Exclamation", "Critical", "Question"].
        """
        payload = {
            "DNSName": machine,
            "Text": message,
            "Title": title,
            "MessageStyle": style,
        }
        self.send_post_request("SendSessionMessage", payload, no_json=True)
