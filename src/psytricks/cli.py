"""Command line interface related functions."""

# pylint: disable-msg=too-many-arguments

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
    help="The command to perform.",
)
@click.option(
    "--machine",
    type=str,
    help=(
        "A machine identifier (FQDN) to perform an action command on. [required for: "
        "'maintenance', 'poweraction']"
    ),
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
@click.option(
    "--message",
    type=click.Path(exists=True),
    help="A JSON file containing the message details (style, title, body).",
)
@click.option(
    "--users",
    help=(
        "One or more usernames, enclosed in quotes, separated by comma but without "
        "space, e.g. 'alice,bob'. [required for: 'setaccess']"
    ),
)
@click.option(
    "--disable",
    is_flag=True,
    help=(
        "Flag to indicate a certain property should be disabled / removed. "
        "[applies to: 'maintenance', 'setaccess']"
    ),
)
def run_cli(config, verbose, command, machine, group, action, message, users, disable):
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
        "disconnect": wrapper.disconnect_session,
        "getaccess": wrapper.get_access_users,
        "machines": wrapper.get_machine_status,
        "maintenance": wrapper.set_maintenance,
        "poweraction": wrapper.perform_poweraction,
        "sendmessage": wrapper.send_message,
        "sessions": wrapper.get_sessions,
        "setaccess": wrapper.set_access_users,
    }
    call_kwargs = {
        "machine": machine,
        "group": group,
        "action": action,
        "message": message,
        "users": users,
        "disable": disable,
    }

    if command == "disconnect" and machine is None:
        raise click.UsageError("Command 'disconnect' requires --machine!")
    if command in ["getaccess", "setaccess"] and group is None:
        raise click.UsageError("Commands 'getaccess'/'setaccess' require --group!")
    if command == "setaccess" and users is None:
        raise click.UsageError("Command 'setaccess' requires --users!")
    if command == "poweraction" and action is None:
        raise click.UsageError("Command 'poweraction' requires --action!")
    if command == "sendmessage" and message is None:
        raise click.UsageError("Command 'sendmessage' requires --message!")
    if command in ["maintenance", "poweraction"] and machine is None:
        raise click.UsageError(
            "Commands 'maintenance'/'poweraction' require --machine!"
        )

    details = call_method[command](**call_kwargs)

    pprint(details)
