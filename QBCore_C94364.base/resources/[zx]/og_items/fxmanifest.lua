fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'og_items'
author 'OG'
description 'OG - قائمة كل الأغراض للأدمن (/items) + استعمال لكل غرض'
version '1.1.0'

client_script 'client.lua'
server_scripts { 'server.lua', 'uses.lua' }

dependencies { 'qb-core', 'qb-inventory' }
