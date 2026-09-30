# System and sensory integration

The app owns these MainActor services. They never retain JourneyEngine.

- Share one `SensorySettings` and create `SensoryService(settings:)` once.
- Ambient audio is OFF by default. `play()` respects that preference;
  `preview(.metro/.rain/.air)` is an explicit eight-second preview.
- Call `stop()` at journey completion/cancellation or when disabling sound.
  `effect(.departure/.arrival/.punch)`, `announce(station:locale:)` and
  `feedback(.departure/.arrival/.punch/.selection)` respect independent switches.
- Trigger transient feedback only for current foreground events, never during
  recovery/reconciliation. Audio interruptions and headphone removal stop playback;
  the engine clock is unaffected. Restart playback only on an explicit user action.
- Create `TicketMotion` only in ticket detail; call `start(reduceMotion:)` on entry,
  restart when the Reduce Motion preference changes, and call `stop()` on exit or
  scene deactivation. Its pitch and roll values are relative and clamped radians.
- Build `SystemJourneySnapshot` after each committed state change. Its `line` and
  `phase` are the domain raw values. Call notification `schedule(_:)` and activity
  `sync(_:)`. Calls are serialized and superseded queued snapshots are skipped.
- Request notification authorization contextually on the first user-initiated
  departure. Notification denial does not block departure.
- Route `metrofocus://journey/<UUID>` and notification `userInfo.journeyID` to the
  current journey. Stale or unknown IDs should simply open the station screen.

App target Info: `UIBackgroundModes = [audio]`, `NSSupportsLiveActivities = YES`,
URL type scheme `metrofocus`. Include `TransitActivityAttributes.swift` in both app
and widget targets; widget extension uses only that shared model and its own files.
No App Group or push entitlement is required for the on-device ActivityKit flow.
Bundle all six WAV files, either flattened or in an `Audio` resource directory.
Do not include this documentation or generator as compiled source.

The widget only extrapolates the current countdown. Its deadline is also staleDate;
stale content prompts the user to open the app. It does not invent a later phase
or promise in-background engine execution. Notification scheduling pre-arranges
the current focus end and following rest end; it never schedules the next focus.
