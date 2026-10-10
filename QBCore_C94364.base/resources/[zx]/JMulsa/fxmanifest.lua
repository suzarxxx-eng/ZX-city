fx_version 'cerulean'
game 'gta5'

author 'Jacobmaate'
description 'University Services Pack'
version 'v1.02'

files {
    'data/vehicles.meta',
	'data/carvariations.meta',
	'data/carcols.meta',
	'data/handling.meta',
	'data/jmulsa_game.dat151.rel',
}

data_file 'HANDLING_FILE' 'data/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/carvariations.meta'
data_file 'AUDIO_GAMEDATA' 'data/jmulsa_game.dat'
client_script 'vehicle_names.lua'