fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ar_policemap'
description 'مركز شرطة ميداني كلين - ينبني بأمر من الأدمن بأي مكان'
version '1.0.0'

shared_scripts {
    'config.lua',
    'layout.lua',
}
client_script 'client.lua'
server_script 'server.lua'

dependency 'qb-core'
