-- Loaded as a shared_script, but in practice only client/client.lua reads it.
-- The server half keeps no configuration of its own.
Config = {}

--Main Config

-- Furthest the beam may be turned away from the vehicle's forward axis, in
-- degrees. The same limit is used for both axes (left/right and up/down); the
-- clamp lives in the rotate command in client/client.lua.
Config.MaxRotation = 90

-- Degrees applied per command invocation. This is a step, not a rate: the key
-- mappings are registered without a +/- prefix, so they fire once per press
-- rather than repeating while the key is held.
Config.MovingSpeed = 5

-- Radius argument of DrawSpotLight, i.e. how wide the cone spreads. The throw
-- distance is a separate, hardcoded value in the draw call. Must stay a float.
Config.SpotlightSize = 20.0

-- Passed straight to DrawSpotLight as three 0-255 channels. Not validated.
Config.SpotlightColor = {
    Red = 255,
    Green = 255,
    Blue = 255
}

-- Keys suggested to a player the *first* time they load the resource. FiveM
-- remembers each player's own choice from then on, keyed by command name, so
-- editing these only affects players who have never run the resource - and
-- renaming a command in Config.Commands resets everyone back to these values.
Config.DefaultKeybinds = {
    Toggle = "END",
    RotateLeft = "LEFT",
    RotateRight = "RIGHT",
    RotateUp = "UP",
    RotateDown = "DOWN"
}

-- Chat command names. Both are registered unrestricted (no ACE check) - the
-- only gate on the feature is the vehicle-class test in the toggle command.
-- Rotate takes the direction as its first argument, e.g. "/movespotlight left".
Config.Commands = {
    Toggle = "spotlight",
    Rotate = "movespotlight"
}

-- Labels shown next to each binding in Settings > Key Bindings > FiveM. These
-- are the only user-facing strings in the resource; there is no chat output,
-- no notification and no locales folder.
Config.Lang = {
    ["toggleSpotlight"] = "Toggle Spotlight",
    ["moveSpotlightUp"] = "Move Spotlight Up",
    ["moveSpotlightDown"] = "Move Spotlight Down",
    ["moveSpotlightLeft"] = "Move Spotlight Left",
    ["moveSpotlightRight"] = "Move Spotlight Right"
}
