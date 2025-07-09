import std/[os, osproc, strutils, sequtils]

type
  TearFreeCommand = enum
    tearFreeOn
    tearFreeOff
    tearFreeStatus

  ApplicationConfiguration = object
    silentMode: bool
    command: TearFreeCommand

  DisplayDevice = object
    identifier: string
    tearFreeState: string

  ApplicationState = object
    errorMessage: string
    displayDevices: seq[DisplayDevice]
    configuration: ApplicationConfiguration

const
  NotificationIcon: string = "monitor"
  NotificationDuration: int = 2

proc getUsageInformation(): string =
  ## Returns a string with the usage information of the application.
  ## Includes a description of commands, options, and usage examples.
  ## The application name is extracted from the executable file.

  let applicationName: string = getAppFilename().lastPathPart
  result = """
TearFree Configuration Manager for X11

USAGE:
  $1 [COMMAND] [OPTIONS]

COMMANDS:
  on        Activate TearFree on all connected displays
  off       Deactivate TearFree on all connected displays
  status    Display current TearFree status for each display

OPTIONS:
  --silent  Suppress notifications, show only console output

EXAMPLES:
  $1 on            # Activate TearFree on all displays
  $1 off           # Deactivate TearFree
  $1 status        # Query current status
  $1 on --silent   # Activate without notifications

NOTES:
  - Requires 'xrandr' to be installed on the system
  - Notifications use 'notify-send' (libnotify)
  - Changes are applied immediately to all detected displays
""".format(
    applicationName
  )

func parseCommandLineArguments(arguments: seq[string]): ApplicationConfiguration =
  ## Parses command-line arguments and returns the application configuration.
  ##
  ## Parameters:
  ## - arguments: Sequence of strings with the provided arguments.
  ##
  ## Returns:
  ## - An instance of `ApplicationConfiguration` with the command and silent mode set.
  ##
  ## Exceptions:
  ## - `ValueError`: If no command is specified or if the command is invalid.

  var silentModeEnabled: bool = false
  var commandArgument: string = ""

  for argument in arguments:
    if argument == "--silent":
      silentModeEnabled = true
    elif commandArgument.len == 0:
      commandArgument = argument

  if commandArgument.len == 0:
    raise newException(ValueError, "No command specified (on, off, status)")

  result.command =
    case commandArgument
    of "on":
      tearFreeOn
    of "off":
      tearFreeOff
    of "status":
      tearFreeStatus
    else:
      raise newException(ValueError, "Invalid command: " & commandArgument)
  result.silentMode = silentModeEnabled

proc detectConnectedDisplays(): seq[string] =
  ## Detects connected displays using `xrandr --prop`.
  ##
  ## Returns:
  ## - A sequence of connected display identifiers (e.g., "HDMI-1", "DP-1").
  ##
  ## Exceptions:
  ## - `OSError`: If executing `xrandr` fails or it is not installed.

  let (commandOutput, exitStatus) = execCmdEx("xrandr --prop")
  if exitStatus != 0:
    raise newException(OSError, "Failed to execute xrandr. Ensure it is installed")

  commandOutput.splitLines().filterIt(it.contains(" connected")).mapIt(
    it.splitWhitespace()[0]
  )

proc queryDisplayTearFreeState(displayIdentifier: string): string =
  ## Queries the TearFree state for a specific display using `xrandr --prop`.
  ##
  ## Parameters:
  ## - displayIdentifier: Identifier of the display (e.g., "HDMI-1").
  ##
  ## Returns:
  ## - The TearFree state ("on", "off", or "unknown" if not found).
  ##
  ## Exceptions:
  ## - `OSError`: If the query with `xrandr` fails.

  let (commandOutput, exitStatus) = execCmdEx("xrandr --prop")
  if exitStatus != 0:
    raise newException(OSError, "Failed to query display status")

  var processingDisplay: bool = false
  for line in commandOutput.splitLines():
    if line.startsWith(displayIdentifier):
      processingDisplay = true
    elif processingDisplay:
      if "TearFree" in line:
        return line.split(":")[1].strip()
      elif line.strip().len == 0:
        break
  "unknown"

func applyTearFreeSetting(displayIdentifier, settingState: string) =
  ## Applies a TearFree setting to a specific display using `xrandr`.
  ##
  ## Parameters:
  ## - displayIdentifier: Identifier of the display (e.g., "HDMI-1").
  ## - settingState: State to apply ("on" or "off").
  ##
  ## Exceptions:
  ## - `OSError`: If applying the setting fails.

  let command: string =
    "xrandr --output " & displayIdentifier & " --set TearFree " & settingState
  if execCmd(command) != 0:
    raise
      newException(OSError, "Failed to apply TearFree setting to " & displayIdentifier)

proc initializeApplicationState(arguments: seq[string]): ApplicationState =
  ## Initializes the application state from command-line arguments.
  ##
  ## Parameters:
  ## - arguments: Sequence of command-line arguments.
  ##
  ## Returns:
  ## - An instance of `ApplicationState` with configuration and detected devices, or an error message if initialization fails.

  try:
    let configuration: ApplicationConfiguration = parseCommandLineArguments(arguments)
    let displayIdentifiers: seq[string] = detectConnectedDisplays()

    var displayDevices: seq[DisplayDevice]
    for identifier in displayIdentifiers:
      displayDevices.add(DisplayDevice(identifier: identifier, tearFreeState: ""))

    result =
      ApplicationState(configuration: configuration, displayDevices: displayDevices)
  except Exception as exception:
    result = ApplicationState(errorMessage: exception.msg)

proc updateApplicationState(applicationState: var ApplicationState) =
  ## Updates the application state based on the specified command.
  ##
  ## Parameters:
  ## - applicationState: Application state to modify.
  ##
  ## If there is a previous error, no action is taken. Otherwise, applies
  ## the command (on, off, status) to the display devices.

  if applicationState.errorMessage.len > 0:
    return

  try:
    case applicationState.configuration.command
    of tearFreeOn:
      for displayDevice in applicationState.displayDevices.mitems:
        applyTearFreeSetting(displayDevice.identifier, "on")
        displayDevice.tearFreeState = "on"
    of tearFreeOff:
      for displayDevice in applicationState.displayDevices.mitems:
        applyTearFreeSetting(displayDevice.identifier, "off")
        displayDevice.tearFreeState = "off"
    of tearFreeStatus:
      for displayDevice in applicationState.displayDevices.mitems:
        displayDevice.tearFreeState =
          queryDisplayTearFreeState(displayDevice.identifier)
  except Exception as exception:
    applicationState.errorMessage = exception.msg

proc displayNotification(messageContent: string, suppressNotifications: bool) =
  ## Displays a notification with `notify-send` or prints to console if suppressed.
  ##
  ## Parameters:
  ## - messageContent: Message to display.
  ## - suppressNotifications: If true, only prints to console.

  if not suppressNotifications:
    try:
      discard execProcess(
        "notify-send",
        args = [
          "-i",
          NotificationIcon,
          "-t",
          $(NotificationDuration * 1000),
          "TearFree",
          messageContent,
        ],
        options = {poUsePath, poDaemon},
      )
    except OSError:
      discard
  echo messageContent

proc renderApplicationState(applicationState: ApplicationState) =
  ## Renders the application state by displaying notifications or errors.
  ##
  ## Parameters:
  ## - applicationState: Application state to render.
  ##
  ## Displays error messages, warnings if no displays are found, or the result of the command applied to each display.

  if applicationState.errorMessage.len > 0:
    displayNotification(
      "Error: " & applicationState.errorMessage,
      applicationState.configuration.silentMode,
    )
    if "invalid" in applicationState.errorMessage.toLowerAscii() or
        "specified" in applicationState.errorMessage.toLowerAscii():
      echo getUsageInformation()
    return

  if applicationState.displayDevices.len == 0:
    displayNotification(
      "No connected displays detected", applicationState.configuration.silentMode
    )
    return

  for displayDevice in applicationState.displayDevices:
    case applicationState.configuration.command
    of tearFreeOn:
      displayNotification(
        "TearFree: On | " & displayDevice.identifier,
        applicationState.configuration.silentMode,
      )
    of tearFreeOff:
      displayNotification(
        "TearFree: Off | " & displayDevice.identifier,
        applicationState.configuration.silentMode,
      )
    of tearFreeStatus:
      displayNotification(
        "TearFree Status: " & displayDevice.tearFreeState & " | " &
          displayDevice.identifier,
        applicationState.configuration.silentMode,
      )

proc main() =
  ## Main function that coordinates the execution of the application.
  ##
  ## Retrieves command-line arguments, initializes and updates the state,
  ## and renders the results. Exits with code 1 if there are errors or no displays are detected.

  let commandLineArguments: seq[string] = commandLineParams()
  var applicationState: ApplicationState =
    initializeApplicationState(commandLineArguments)
  updateApplicationState(applicationState)
  renderApplicationState(applicationState)

  if applicationState.errorMessage.len > 0 or
      (
        applicationState.displayDevices.len == 0 and
        applicationState.errorMessage.len == 0
      ):
    quit(1)

when isMainModule:
  main()
