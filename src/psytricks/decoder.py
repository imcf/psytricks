"""PowerShell JSON decoding helper."""

import re
from datetime import datetime

from loguru import logger as log

from .mappings import by_keyword


def parse_powershell_json(json_dict):
    """Hook for `json.loads()` to process PowerShell 5.1 / Citrix JSON.

    Windows PowerShell up to version 5.1 will produce strings in the format
    `/Date(<ms-since-epoch>)/` when converting a timestamp to JSON using the
    built-in `ConvertTo-Json` cmdlet. Python's `json.load()` and `json.loads()`
    methods will simply return those as plain strings, which is not desired.

    On top of that the literal descriptions given by the Citrix cmdlets for the
    various states (power, registration, ...) are transformed into numbers by
    PowerShell when converting to JSON.

    This function can be supplied via the `object_hook` parameter when calling
    `load()` / `loads()` to properly parse the date strings into Python datetime
    objects. In addition the numerical values for various `*State` fields will
    be mapped to their descriptive, human-readable names (all lowercase).

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
        # log.trace(f"{key} -> {value}")
        if key.endswith("Time") and value is not None and "/Date(" in value:
            log.trace(f"{key} -> {value}")
            epoch_ms = re.split(r"\(|\)", value)[1]
            ret[key] = datetime.fromtimestamp(int(epoch_ms[:10]))
        elif key in by_keyword:
            mapping = by_keyword[key]
            mapped_value = mapping[value]
            log.trace(f"{key}: {value} -> {mapped_value}")
            ret[key] = mapped_value
        else:
            ret[key] = value

    return ret
