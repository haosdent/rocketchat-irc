Package.describe({
	name: 'rocketchat:irc',
	version: '0.0.1',
	summary: '',
	git: ''
});

Npm.depends({
	'irc': '0.3.12'
});

Package.onUse(function(api) {
	api.versionsFrom('1.0');

	api.use('coffeescript');

	api.addFiles('irc.server.coffee', 'server');

	api.export(['Irc'], ['server']);
});

Package.onTest(function(api) {

});
