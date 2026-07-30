-- Server side storage for spotlight data
-- Authoritative state, keyed by vehicle network id, so that every client draws
-- the same beam in the same place. Held in memory only: it is empty again
-- after a restart, and nothing prunes entries for vehicles that no longer
-- exist. See docs/known-issues.md.
local spotlights = {}

-- Add or update spotlight data
local function setSpotlightData(vehicleId, active, heading, pitch)
    if not spotlights[vehicleId] then
        spotlights[vehicleId] = {}
    end
    spotlights[vehicleId].active = active
    spotlights[vehicleId].headingOffset = heading
    spotlights[vehicleId].pitchOffset = pitch
end

-- Synchronize spotlight data with a specific player or all players (-1 for all)
-- Sends the entire table rather than a delta; the receiving client replaces
-- its copy outright. Every call site currently passes -1.
local function syncSpotlights(source)
    TriggerClientEvent("spotlight:syncSpotlights", source, spotlights)
end

-- Toggle spotlight
-- The vehicle-class and aircraft checks live in the client command only; this
-- handler trusts whatever network id it is handed and never inspects `source`.
RegisterNetEvent("spotlight:toggle")
AddEventHandler(
    "spotlight:toggle",
    function(vehicleId, active)
        -- Carry the previous aim across a toggle, so switching the beam back on
        -- points it where it was left rather than straight ahead.
        local heading = spotlights[vehicleId] and spotlights[vehicleId].headingOffset or 0
        local pitch = spotlights[vehicleId] and spotlights[vehicleId].pitchOffset or 0
        setSpotlightData(vehicleId, active, heading, pitch)
        syncSpotlights(-1) -- Sync with all players
    end
)

-- Update the heading and pitch offsets of a spotlight
RegisterNetEvent("spotlight:updateHeadingPitch")
AddEventHandler(
    "spotlight:updateHeadingPitch",
    function(vehicleId, headingOffset, pitchOffset)
        if spotlights[vehicleId] then
            -- Update the heading and pitch offsets
            spotlights[vehicleId].headingOffset = headingOffset
            spotlights[vehicleId].pitchOffset = pitchOffset
        else
            -- Initialize the spotlight data if it doesn't exist
            -- No `active` field is set here; clients read a missing field as
            -- off, so an aim update on its own never lights a beam.
            spotlights[vehicleId] = {
                headingOffset = headingOffset,
                pitchOffset = pitchOffset
            }
        end
        -- Broadcast the updated spotlight data to all clients
        TriggerClientEvent("spotlight:syncSpotlights", -1, spotlights)
    end
)

-- When a player connects, send them the current state of all spotlights
-- Note: playerSpawned is raised on the client by spawnmanager. There is no
-- server-side event of that name and this is not a RegisterNetEvent, so this
-- handler does not currently run - a player joining while a beam is already on
-- sees nothing until the next toggle or aim forces a broadcast.
-- See docs/known-issues.md.
AddEventHandler(
    "playerSpawned",
    function()
        syncSpotlights(-1)
    end
)
