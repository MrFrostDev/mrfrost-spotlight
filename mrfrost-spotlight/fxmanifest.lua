fx_version "cerulean"
game "gta5"

name "mrfrost-spotlight"
author "MrFrost"
description "Spotlight Script for Emegrency Vehicles"
version "1.0.1"

lua54 "on"

shared_scripts {
	"shared/config.lua"
}

client_scripts {
	"client/client.lua"
}

server_scripts {
	"server/server.lua"
}

-- Only meaningful when the resource is packed for FiveM's asset escrow: it
-- keeps the config readable and editable. Harmless otherwise.
escrow_ignore {
	"shared/config.lua"
}
