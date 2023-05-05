"""Literals definitions to improve documentation and type checking."""

from typing import Literal


RequestName = Literal[
    "DisconnectSession",
    "GetAccessUsers",
    "GetMachineStatus",
    "GetSessions",
    "MachinePowerAction",
    "SendSessionMessage",
    "SetAccessUsers",
    "SetMaintenanceMode",
]
"""Valid command names for the PowerShell wrapper script."""

Action = Literal[
    "reset",
    "restart",
    "resume",
    "shutdown",
    "suspend",
    "turnoff",
    "turnon",
]
"""Valid power action names."""


MsgStyle = Literal["Information", "Exclamation", "Critical", "Question"]
"""Valid style names to be used for desktop pop-up messages."""
