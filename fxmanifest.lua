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

ui_page "html/index.html"

files {
    "html/index.html",
    "html/style.css",
    "html/index.js",
}

shared_scripts {
    '@ox_lib/init.lua',
    "config.lua",
    "bridge/**/client.lua",
    "bridge/**/server.lua",
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    "server/*.lua"
}

client_scripts {
    "client/*.lua"
}
