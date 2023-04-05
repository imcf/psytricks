"""Command line interface related functions."""

import sys
from pprint import pprint

import click
from loguru import logger as log

from .wrapper import PSyTricksWrapper


def configure_logging(verbose: int):
    """Configure loguru logging / change log level.

    Parameters
    ----------
    verbose : int
        The desired log level, 0=WARNING (do not change the logger config),
        1=INFO, 2=DEBUG, 3=TRACE. Higher values will map to TRACE.
    """
    level = "WARNING"
    if verbose == 1:
        level = "INFO"
    elif verbose == 2:
        level = "DEBUG"
    elif verbose >= 3:
        level = "TRACE"
    # set up logging, loguru requires us to remove the default handler and
    # re-add a new one with the desired log-level:
    log.remove()
    log.add(sys.stderr, level=level)
    log.info(f"Set logging level to [{level}] ({verbose}).")


@click.command(help="Run the PSyTricks command line interface.")
@click.option(
    "--config",
    type=click.Path(exists=True),
    help="A JSON configuration file.",
    required=True,
)
@click.option(
    "-v",
    "--verbose",
    count=True,
    help="Increase logging verbosity, may be repeated up to 3 times.",
)
@click.option(
    "--command",
    type=click.Choice(
        [
            "disconnect",
            "getaccess",
            "machines",
            "maintenance",
            "poweraction",
            "sendmessage",
            "sessions",
            "setaccess",
        ]
    ),
    required=True,
)
@click.option(
    "--machine",
    type=str,
    help="""A machine ID to perform an action command on. [required for: 'getaccess',
    'setaccess']""",
)
@click.option(
    "--group",
    type=str,
    help="A Delivery Group name. [required for: 'getaccess', 'setaccess']",
)
@click.option(
    "--action",
    type=click.Choice(
        [
            "shutdown",
            "restart",
        ]
    ),
    required=False,
    help="The power action to perform on a machine. [required for: 'poweraction']",
)
@click.option("--message")
@click.option("--users")
def run_cli(config, verbose, command, machine, group, action, message, users):
    """Create a wrapper object and call the method requested on the command line.

    Parameters
    ----------
    config : str
        Path to the JSON config file required by the PowerShell script.
    verbose : int
        The logging verbosity.
    command : str
        The command indicating which wrapper method to call.
    """
    configure_logging(verbose)
    wrapper = PSyTricksWrapper(conffile=config)
    call_method = {
        "sessions": wrapper.get_sessions,
        "machines": wrapper.get_machine_status,
        "disconnect": wrapper.disconnect_session,
    }
    call_kwargs = {
        "machine": machine,
        "group": group,
        "action": action,
        "message": message,
        "users": users,
    }
    details = call_method[command](**call_kwargs)

    pprint(details)
