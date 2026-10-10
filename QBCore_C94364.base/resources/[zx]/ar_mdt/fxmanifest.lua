fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_mdt'
description 'MDT الأمن العام - مواطنين، مركبات، تقارير، أوامر قبض، تعميمات، عقوبات، وحدات'
version '1.0.0'

shared_script 'config.lua'
client_script 'client.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

dependencies { 'qb-core', 'oxmysql' }
