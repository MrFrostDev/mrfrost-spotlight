# Known issues

Everything below was found by reading the source, not by testing against a live
server, so a few entries are descriptions of code that looks wrong rather than
confirmed misbehaviour. Nothing here has been fixed — the resource is published
as it was last run.

Line numbers refer to the files as shipped.

## Beam origin mixes two different bones

`client/client.lua:126-129`, `client/client.lua:159-161`

Two bone positions are looked up — `door_dside_f` into `coords` and `windscreen`
into `windowCoords` — but the `DrawSpotLight` call passes
`coords.x, windowCoords.y, coords.z`. The Y component comes from one bone and
the X and Z from the other, so the emitter sits at a world-space point that is
on neither bone. Because the two bones are offset from each other along the
vehicle's local axes, the error changes as the vehicle rotates: the light sits
roughly in the right place when the car faces north or south, and drifts
sideways out of the bodywork when it faces east or west.

A fix is to choose one bone and pass all three components from it, for example
`windowCoords.x, windowCoords.y, windowCoords.z`, or to keep the door bone for
the mount point and add a fixed forward offset with
`GetOffsetFromEntityInWorldCoords`.

## A missing bone is not handled

`client/client.lua:126-129`

`GetEntityBoneIndexByName` returns `-1` when the bone does not exist. Not every
class 18 vehicle has both `door_dside_f` and `windscreen` — custom and add-on
emergency models frequently do not — and the result is passed to
`GetWorldPositionOfEntityBone` without a check, so the beam is drawn from
whatever that native returns for an invalid index.

A fix is to test each index for `-1` and fall back to `GetEntityCoords` or a
fixed offset from the vehicle.

## The server's playerSpawned handler never runs

`server/server.lua:70-75`

`playerSpawned` is raised on the *client* by `spawnmanager`. There is no
server-side event of that name, and the handler is registered with
`AddEventHandler` rather than `RegisterNetEvent`, so a client could not trigger
it over the network either. The practical effect is that a player who joins
while a spotlight is already on sees nothing until somebody toggles or aims a
spotlight and forces a fresh broadcast.

A fix is for the client to trigger its own server event once it has spawned, and
for the server to answer with `syncSpotlights(source)`.

## syncSpotlights is never called with a real player id

`server/server.lua:21-23`, `server/server.lua:37`, `server/server.lua:73`

`syncSpotlights(source)` takes a target so it can send state to one player, but
both call sites pass `-1` (everyone). The single-player path is unused, which is
what makes the join case above awkward to fix in place.

## Neither server event validates the caller

`server/server.lua:28-39`, `server/server.lua:42-62`

`spotlight:toggle` and `spotlight:updateHeadingPitch` use the `vehicleId` the
client sends and never look at `source`. The vehicle-class and aircraft checks
that gate the feature live entirely in the client command
(`client/client.lua:43-44`), so a modified client can switch a spotlight on for
any networked vehicle on the map, including vehicles it is nowhere near and
vehicles that are not emergency class. There is also no rate limiting, and every
aim update rebroadcasts the whole table to every player
(`server/server.lua:60`), so the events are a cheap way to generate traffic.

A fix is to resolve the caller's vehicle server-side with
`GetVehiclePedIsIn(GetPlayerPed(source))`, compare it against the network id in
the payload, repeat the class check on the server, and broadcast only the entry
that changed.

## Spotlight state is never cleaned up

`server/server.lua:6`

Entries are added to `spotlights` and never removed. Nothing prunes them when a
vehicle is deleted, when the driver leaves, or when a player disconnects, so the
table grows for the lifetime of the server — and the full table is sent to every
client on every change. Network ids are recycled, so a freshly spawned vehicle
can inherit a stale entry and appear with its spotlight already on and aimed.

A fix is a periodic sweep that drops any id for which
`NetworkGetEntityFromNetworkId` no longer resolves to an existing entity, plus a
`playerDropped` handler.

## A parked vehicle keeps its beam

`client/client.lua:32-57`

Both commands require the player to be inside the vehicle. Nothing turns the
beam off when the driver gets out, dies, or the vehicle is abandoned, so a lit
spotlight stays lit until someone gets back in and toggles it. Combined with the
entry above, an abandoned car can be left shining for the rest of the session.

A fix is a client-side watch on the local player leaving a vehicle whose
spotlight is on, triggering `spotlight:toggle` with `false`.

## `if vehicle then` is always true

`client/client.lua:67` (also `client/client.lua:42` and `client/client.lua:122`)

`GetVehiclePedIsIn` returns `0` when the ped is on foot, and `0` is truthy in
Lua. In the aim command that means the body always runs: on foot it takes a
network id from entity `0`, calls `initializeSpotlightData` with it and inserts a
junk entry into the local table before returning at the `active` check. The
toggle command is saved only by the class check that immediately follows.

A fix is to compare explicitly, `if vehicle ~= 0 then`.

## The per-direction clamps are redundant and use the wrong bound

`client/client.lua:85-93`

Each branch clamps against the limit it cannot reach. `up` adds
`Config.MovingSpeed` and then takes `math.max(..., -Config.MaxRotation)`, which
can only bind if the value is falling; `down` subtracts and takes `math.min`
against the positive limit. The behaviour is nevertheless correct, because lines
96-97 apply a proper symmetric clamp to both axes afterwards — but the branch
code reads as if it enforces something and does not.

A fix is to drop the `math.max`/`math.min` from the four branches and rely on the
clamp that follows.

## The draw thread runs every frame regardless

`client/client.lua:113-117`

`Citizen.Wait(0)` keeps the loop at full framerate even when `activeSpotlights`
is empty or every entry is inactive, and the loop walks the entire table — which
includes every spotlight on the server, not only the ones near the player.

A fix is to wait a few hundred milliseconds while nothing is active and drop
back to `0` as soon as an active entry appears, and to skip entries whose
vehicle is beyond the beam's useful distance.

## Optimistic local writes can be overwritten by an older broadcast

`client/client.lua:99-103`, `server/server.lua:60`

The aim command writes the new offsets into the local table and then tells the
server, which replies to everyone with a full replacement table. A burst of key
presses can therefore be followed by an older snapshot arriving late and pushing
the beam back a step.

A fix is to send only the delta and let the server be authoritative, or to
ignore inbound sync for the vehicle the local player is currently aiming.

## Beam parameters are hardcoded

`client/client.lua:168-172`

Distance `100.0`, brightness `1.0`, hardness `0.0` and falloff `1.0` are literals
in the `DrawSpotLight` call, while only the radius and the colour come from the
config. Servers that want a longer or softer beam have to edit the client
script.

## The emergency-class filter cannot be configured

`client/client.lua:44`

`GetVehicleClass(vehicle) == 18` is written inline. There is no way to allow an
emergency-liveried vehicle that sits in another class, or to restrict the
feature to a specific list of models, without editing the script.

A fix is a `Config.AllowedClasses` list, checked with a lookup rather than an
equality test.

## Minor

- `fxmanifest.lua:6` — the description reads "Emegrency Vehicles". The same typo
  appears in the heading of the resource's own inner `README.md`. Cosmetic; the
  description string only shows up in server tooling.
- `fxmanifest.lua:25-27` — the `escrow_ignore` block only means something for
  resources published through FiveM's asset escrow. It is harmless leftover
  metadata in an open-source release.
- `mrfrost-spotlight/README.md` — the resource folder still carries the short
  original README, which now duplicates and contradicts the repository README at
  the root (it lists installation as "move the folder to your server
  resources"). Worth deleting or reducing to a pointer.
- `server/server.lua:50-57` — the fallback branch of `spotlight:updateHeadingPitch`
  creates an entry with no `active` field. Clients treat the missing field as
  off, so this is safe, but the table ends up with two shapes of entry.
