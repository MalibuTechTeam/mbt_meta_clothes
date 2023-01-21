fx_version "cerulean"

use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

author "Malibù Tech Team"

description "mbt_meta_clothes"

version "1.1.2"

ui_page "html/index.html"
files {
    "html/index.html",
    "html/style.css",
    "html/index.js",
    "html/*.svg",
}

shared_scripts {
    '@ox_lib/init.lua',
    "config.lua"
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    "server/*.lua"
}

client_scripts {
    "client/*.lua"
}

dependencies { "ox_lib", "ox_inventory" }
