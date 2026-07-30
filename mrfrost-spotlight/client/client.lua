-- The server owns the authoritative spotlight table; this is a local mirror of
-- it so that every player draws every beam, not just the driver operating it.
-- Keyed by network id rather than entity handle, because entity handles differ
-- from client to client while network ids are the same everywhere.
local activeSpotlights = {}

-- Initialize the spotlight data with headingOffset
-- Offsets are relative to the vehicle, so the beam keeps pointing the same way
-- with respect to the bodywork as the vehicle turns.
local function initializeSpotlightData(vehicleId)
    if not activeSpotlights[vehicleId] then
        activeSpotlights[vehicleId] = {
            active = false,
            headingOffset = 0, -- This is the variable for relative heading
            pitchOffset = 0 -- This is the new variable for relative pitch
        }
    end
end

-- Receive updated spotlight state from the server
-- The whole table is replaced rather than merged, so anything added locally
-- (see initializeSpotlightData) is discarded the next time the server speaks.
RegisterNetEvent("spotlight:syncSpotlights")
AddEventHandler(
    "spotlight:syncSpotlights",
    function(spotlights)
        activeSpotlights = spotlights
    end
)

-- Command to toggle spotlight
RegisterCommand(
    Config.Commands.Toggle,
    function()
        -- false = must be sitting in it, not merely entering it
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        -- Class 18 is the Emergency class. Aircraft are excluded separately
        -- because helicopters already have their own searchlight natives, and
        -- the bone lookups further down assume a road vehicle.
        -- Note: GetVehiclePedIsIn returns 0 on foot and 0 is truthy in Lua, so
        -- the class test is what actually rejects the on-foot case here.
        if
            vehicle and not IsThisModelAPlane(GetEntityModel(vehicle)) and not IsThisModelAHeli(GetEntityModel(vehicle)) and
                GetVehicleClass(vehicle) == 18
         then
            local vehicleId = NetworkGetNetworkIdFromEntity(vehicle)
            -- nil for a vehicle the server has never mentioned, which "not"
            -- turns into true - so the first press on any vehicle switches on.
            local active = activeSpotlights[vehicleId] and activeSpotlights[vehicleId].active
            active = not active
            -- The local copy is deliberately left alone: the server's reply
            -- broadcast is what actually flips the beam, here and everywhere.
            TriggerServerEvent("spotlight:toggle", vehicleId, active)
        end
    end,
    false
)

-- Command to move spotlight
-- args[1] is the direction, supplied either by the player typing
-- "/movespotlight left" or by the key mappings at the bottom of this file,
-- which bake the direction into the command string they bind.
RegisterCommand(
    Config.Commands.Rotate,
    function(_, args)
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle then
            local vehicleId = NetworkGetNetworkIdFromEntity(vehicle)
            -- Re-created on every press because a sync from the server
            -- replaces the whole table and can drop the entry again.
            initializeSpotlightData(vehicleId)
            if not activeSpotlights[vehicleId].active then
                return
            end
            local headingOffset = activeSpotlights[vehicleId].headingOffset
            local pitchOffset = activeSpotlights[vehicleId].pitchOffset

            -- Sign convention, matching the vector maths in the draw thread
            -- below: a positive pitch tilts the beam up, and a positive
            -- heading turns it left, because GTA headings increase
            -- counter-clockwise when seen from above.
            -- The math.max/math.min pairs here each guard the limit the value
            -- is moving away from, so they never bind; the clamp that actually
            -- enforces Config.MaxRotation is the symmetric one just below.
            if args[1] == "up" then
                pitchOffset = math.max(pitchOffset + Config.MovingSpeed, -Config.MaxRotation)
            elseif args[1] == "down" then
                pitchOffset = math.min(pitchOffset - Config.MovingSpeed, Config.MaxRotation)
            elseif args[1] == "left" then
                headingOffset = math.max(headingOffset + Config.MovingSpeed, -Config.MaxRotation)
            elseif args[1] == "right" then
                headingOffset = math.min(headingOffset - Config.MovingSpeed, Config.MaxRotation)
            end

            -- Update the spotlight heading and pitch offsets without exceeding the max rotation
            headingOffset = math.max(math.min(headingOffset, Config.MaxRotation), -Config.MaxRotation)
            pitchOffset = math.max(math.min(pitchOffset, Config.MaxRotation), -Config.MaxRotation)

            activeSpotlights[vehicleId].headingOffset = headingOffset
            activeSpotlights[vehicleId].pitchOffset = pitchOffset

            -- Send the new heading and pitch offsets to the server to update
            TriggerServerEvent("spotlight:updateHeadingPitch", vehicleId, headingOffset, pitchOffset)
        end
    end,
    false
)

-- Drawing the spotlight
-- DrawSpotLight is a per-frame native: the light only exists for the frame it
-- is called on, so this has to run every tick for as long as any beam is lit.
-- The table covers every spotlight on the server, not just nearby ones.
Citizen.CreateThread(
    function()
        while true do
            Citizen.Wait(0)
            for vehicleId, spotlightData in pairs(activeSpotlights) do
                -- The vehicle may not be streamed in on this client, in which
                -- case there is no local entity to hang the light off.
                if NetworkDoesNetworkIdExist(vehicleId) then
                    local vehicle = NetworkGetEntityFromNetworkId(vehicleId)
                    if vehicle and spotlightData.active then
                        -- Mount point: the driver's door and the windscreen.
                        -- Both return -1 on a model that lacks the bone, which
                        -- is not checked for here.
                        local door = GetEntityBoneIndexByName(vehicle, "door_dside_f")
                        local windscreen = GetEntityBoneIndexByName(vehicle, "windscreen")
                        local coords = GetWorldPositionOfEntityBone(vehicle, door)
                        local windowCoords = GetWorldPositionOfEntityBone(vehicle, windscreen)
                        local currentVehicleHeading = GetEntityHeading(vehicle) % 360
                        local headingOffset = spotlightData.headingOffset
                        local pitchOffset = spotlightData.pitchOffset

                        -- Calculate the absolute heading and pitch of the spotlight
                        local absoluteSpotlightHeading = (currentVehicleHeading + headingOffset) % 360
                        local absoluteSpotlightPitch = pitchOffset -- Pitch is now an offset

                        local radHeading = math.rad(absoluteSpotlightHeading)
                        local radPitch = math.rad(absoluteSpotlightPitch)

                        -- Calculate the forward vector based on the absolute heading and pitch
                        -- Standard GTA heading-to-direction conversion: heading
                        -- 0 faces +Y (north) and grows counter-clockwise, hence
                        -- the negated sine on X. cos(pitch) shortens the
                        -- horizontal part as the beam tilts away from level.
                        local forwardX = -math.sin(radHeading) * math.cos(radPitch)
                        local forwardY = math.cos(radHeading) * math.cos(radPitch)
                        local forwardZ = math.sin(radPitch)
                        local forwardVector = vector3(forwardX, forwardY, forwardZ)

                        -- Argument order: position, direction, colour, then
                        -- distance, brightness, hardness, radius, falloff.
                        -- Only the radius and the colour come from Config; the
                        -- rest are fixed here.
                        -- Note the position mixes the two bones - X and Z come
                        -- from the door, Y from the windscreen. See
                        -- docs/known-issues.md.
                        DrawSpotLight(
                            coords.x,
                            windowCoords.y,
                            coords.z,
                            forwardVector.x,
                            forwardVector.y,
                            forwardVector.z,
                            Config.SpotlightColor.Red,
                            Config.SpotlightColor.Green,
                            Config.SpotlightColor.Blue,
                            100.0,
                            1.0,
                            0.0,
                            Config.SpotlightSize,
                            1.0
                        )
                    end
                end
            end
        end
    end
)

-- Key bindings. The keys named here are only defaults offered the first time a
-- player loads the resource; FiveM stores each player's own choice against the
-- command string, so renaming a command in Config resets everyone's binding.
-- The four aim bindings work by binding a command *with its argument already
-- attached*, which is why RegisterCommand only needs one handler for them.
RegisterKeyMapping(Config.Commands.Toggle, Config.Lang["toggleSpotlight"], "keyboard", Config.DefaultKeybinds.Toggle)

RegisterKeyMapping(
    Config.Commands.Rotate .. " up",
    Config.Lang["moveSpotlightUp"],
    "keyboard",
    Config.DefaultKeybinds.RotateUp
)

RegisterKeyMapping(
    Config.Commands.Rotate .. " down",
    Config.Lang["moveSpotlightDown"],
    "keyboard",
    Config.DefaultKeybinds.RotateDown
)

RegisterKeyMapping(
    Config.Commands.Rotate .. " left",
    Config.Lang["moveSpotlightLeft"],
    "keyboard",
    Config.DefaultKeybinds.RotateLeft
)

RegisterKeyMapping(
    Config.Commands.Rotate .. " right",
    Config.Lang["moveSpotlightRight"],
    "keyboard",
    Config.DefaultKeybinds.RotateRight
)
