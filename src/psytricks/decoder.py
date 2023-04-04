"""PowerShell JSON decoding helper."""

import re
from datetime import datetime

from loguru import logger as log


def parse_powershell_json(json_dict):
    """Hook for `json.loads()` to parse PowerShell 5.1 JSON specificities.

    Windows PowerShell up to version 5.1 will produce strings in the format
    `/Date(<ms-since-epoch>)/` when converting a timestamp to JSON using the
    built-in `ConvertTo-Json` cmdlet. Python's `json.load()` and `json.loads()`
    methods will simply return those as plain strings, which is not desired.
    This function can be supplied via the `object_hook` parameter when calling
    them to properly parse such strings into datetime objects.

    Parameters
    ----------
    json_dict : dict
        The literal decoded object as a dict (see the Python `json` package docs
        for details).

    Returns
    -------
    dict
    """
    ret = {}
    for key, value in json_dict.items():
        if key.endswith("Time") and value is not None and "/Date(" in value:
            log.warning(f"{key} -> {value}")
            epoch_ms = re.split(r"\(|\)", value)[1]
            ret[key] = datetime.fromtimestamp(int(epoch_ms[:10]))
        else:
            ret[key] = value

    return ret
