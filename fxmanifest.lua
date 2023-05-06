fx_version "cerulean"

use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

name 'mbt_meta_clothes'
author "Malibù Tech Team"
version "1.2.0"
repository 'https://github.com/MalibuTechTeam/mbt_meta_clothes'
description "mbt_meta_clothes"

dependencies {
	'/server:5848',
	'/onesync'
}

ui_page "web/index.html"

files {
    "web/index.html",
    "web/style.css",
    "web/index.js",
}

shared_scripts {
    -- '@ox_lib/init.lua',
    "config.lua",
}

client_scripts{
    "modules/bridge/**/client.lua",
    "modules/functions/**/client.lua",
    "modules/core/**/client.lua",
}

server_scripts{
    "modules/core/**/server.lua",
    "modules/bridge/**/server.lua",
    "modules/functions/**/server.lua"
}
