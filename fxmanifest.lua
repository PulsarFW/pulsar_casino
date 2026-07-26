fx_version 'cerulean'
games({ 'gta5' })

name 'Pulsar Casino'
description 'Diamond Casino games'
author 'Artmines - maintained for Pulsar Framework'
url 'https://pulsarframe.work'
version 'v1.0.0'

version_check 'yes'
github 'https://github.com/PulsarFW/pulsar_casino'

client_script '@pulsar_core/components/cl_error.lua'
shared_script '@pulsar_core/core/sh_pulsar.lua'
client_script '@pulsar_pwnzor/client/check.lua'

author 'Pulsar Team'
version 'v1.0.0'
url 'https://pulsarfw.com'

server_scripts({
	'config/**/*.lua',
	'shared/**/*.lua',
	'server/**/*.lua',
})

client_scripts({
	'shared/**/*.lua',
	'client/**/*.lua',
})

lua54 'yes'
