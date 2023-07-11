fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

name 'mbt_meta_clothes'
author 'Malibù Tech Team'
version '1.2.0'
repository 'https://github.com/MalibuTechTeam/mbt_meta_clothes'
description 'mbt_meta_clothes'

dependencies {
	'/server:6116',
	'/onesync',
    'oxmysql',
}

shared_scripts {
    'config.lua',
    'modules/module.lua'
}

server_scripts{
    '@oxmysql/lib/MySQL.lua',
    'modules/**/server.lua',
    'modules/bridge/**/server.lua',
    'core/**/server.lua',
}

client_scripts{
    'modules/**/client.lua',
    'modules/bridge/**/client.lua',
    'core/**/client.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/index.js',
    'web/image/*.png',
}
