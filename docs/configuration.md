# Configuration

All settings live in `mrfrost-spotlight/shared/config.lua`. The file is declared
as a `shared_script`, so the same table is read by both `client/client.lua` and
the pause-menu key bindings; the server half of the resource does not read it.
It is also listed in `escrow_ignore`, which means it stays as plain text even if
the resource is packed for FiveM's asset escrow.

Changes take effect on `restart mrfrost-spotlight`, with the exception of the
key bindings — see the note under `Config.DefaultKeybinds`.

## Config.MaxRotation

| | |
| --- | --- |
| Type | number (degrees) |
| Default | `90` |

The furthest the beam may be turned away from the direction the vehicle is
facing. The same value is used for both axes: left/right (`headingOffset`) and
up/down (`pitchOffset`) are each clamped to the range
`-Config.MaxRotation` to `+Config.MaxRotation` in `client/client.lua:96-97`.

At the default of `90` the beam can point straight out of either side of the
vehicle, and straight up or straight down, but never behind it. There is no way
to set a different limit for the two axes without editing the client script.

## Config.MovingSpeed

| | |
| --- | --- |
| Type | number (degrees) |
| Default | `5` |

How far the beam moves for one invocation of the aim command. Despite the name
this is a step size, not a rate: the command is bound through
`RegisterKeyMapping` without a `+`/`-` prefix, so it fires once per key press
rather than continuously while the key is held. With the default of `5` it takes
18 presses to sweep from one extreme to the other.

Larger values aim faster but coarser. Values that do not divide `MaxRotation`
evenly simply stop at the clamp.

## Config.SpotlightSize

| | |
| --- | --- |
| Type | number (float) |
| Default | `20.0` |

Passed as the `radius` argument of the `DrawSpotLight` native
(`client/client.lua:171`). It controls how wide the cone spreads, not how far it
reaches — the throw distance is a hardcoded `100.0` in the same call. Keep the
trailing `.0`; the native expects a float.

## Config.SpotlightColor

| | |
| --- | --- |
| Type | table of three numbers |
| Default | `{ Red = 255, Green = 255, Blue = 255 }` |

The beam colour, as three 0-255 channels, passed straight to `DrawSpotLight`.
The default is white. The values are not validated or clamped, so numbers
outside 0-255 are handed to the native as-is.

| Field | Type | Default |
| --- | --- | --- |
| `Red` | number, 0-255 | `255` |
| `Green` | number, 0-255 | `255` |
| `Blue` | number, 0-255 | `255` |

## Config.DefaultKeybinds

| | |
| --- | --- |
| Type | table of strings |
| Default | see below |

The key each binding is *suggested* with the first time a player runs the
resource. FiveM stores the player's own choice from that point on, so editing
this table does not move the key for anyone who has already loaded the resource
once — it only changes the default offered to new players. Existing players
rebind under *Settings > Key Bindings > FiveM*.

| Field | Default | Bound command |
| --- | --- | --- |
| `Toggle` | `"END"` | `Config.Commands.Toggle` |
| `RotateLeft` | `"LEFT"` | `Config.Commands.Rotate .. " left"` |
| `RotateRight` | `"RIGHT"` | `Config.Commands.Rotate .. " right"` |
| `RotateUp` | `"UP"` | `Config.Commands.Rotate .. " up"` |
| `RotateDown` | `"DOWN"` | `Config.Commands.Rotate .. " down"` |

Values are FiveM keyboard key names, the same ones the pause menu uses.

## Config.Commands

| | |
| --- | --- |
| Type | table of strings |
| Default | `{ Toggle = "spotlight", Rotate = "movespotlight" }` |

The chat command names. Both are registered with `RegisterCommand(..., false)`,
so they are unrestricted and any player may run them; access control comes from
the vehicle-class check in the toggle command, not from an ACE permission.

| Field | Default | Effect |
| --- | --- | --- |
| `Toggle` | `"spotlight"` | `/spotlight` turns the beam on or off for the vehicle you are in. |
| `Rotate` | `"movespotlight"` | `/movespotlight <up\|down\|left\|right>` aims it. Any other argument is accepted and does nothing. |

Renaming a command also renames the key mapping it is attached to. Because FiveM
keys a player's saved binding to the command name, a rename resets everyone's
key back to the value in `Config.DefaultKeybinds`.

## Config.Lang

| | |
| --- | --- |
| Type | table of strings |
| Default | see below |

The descriptions shown next to each binding in the pause-menu Key Bindings list.
These are the only user-facing strings in the resource — there are no chat
messages, notifications or UI, and no `locales/` folder.

| Key | Default |
| --- | --- |
| `toggleSpotlight` | `"Toggle Spotlight"` |
| `moveSpotlightUp` | `"Move Spotlight Up"` |
| `moveSpotlightDown` | `"Move Spotlight Down"` |
| `moveSpotlightLeft` | `"Move Spotlight Left"` |
| `moveSpotlightRight` | `"Move Spotlight Right"` |

All five keys are read in `client/client.lua`; none are unused, and none are
referenced without being defined.

## Not configurable

These values are worth knowing about because they are fixed in the client script
rather than exposed in the config:

| Value | Location | Notes |
| --- | --- | --- |
| Vehicle class `18` | `client/client.lua:44` | The Emergency class. The toggle command refuses every other class, and additionally refuses planes and helicopters. |
| Beam distance `100.0` | `client/client.lua:168` | How far the light throws. |
| Beam brightness `1.0` | `client/client.lua:169` | |
| Beam hardness `0.0` | `client/client.lua:170` | Edge softness of the cone. |
| Beam falloff `1.0` | `client/client.lua:172` | |
| Bone names `door_dside_f`, `windscreen` | `client/client.lua:126-127` | Where the beam is emitted from. Vehicles without these bones are not handled. |
