net = Npm.require('net')

ircClientMap = {}

# grrrr, Meteor.bindEnvironment doesn't preserve `this` apparently
bind = (f) ->
	g = Meteor.bindEnvironment (self, args...) -> f.apply(self, args)
	(args...) -> g @, args...

class IrcClient
	constructor: (@user) ->
		ircClientMap[@user._id] = this
		port = 6667
		host = 'irc.freenode.net'
		@msgBuf = []
		@isConnected = false
		@socket = new net.Socket
		@socket.setNoDelay
		@socket.setEncoding 'utf-8'
		@socket.connect port, host, @onConnect
		@socket.on 'data', bind @onReceiveRawMessage
		@socket.on 'close', @onClose
		@receiveMessageRegex = /^:(\S+)!~\S+ PRIVMSG (\S+) :(.+)\r\n$/

	onConnect: () =>
		console.log @user.username, 'connect success.'
		@socket.write "NICK #{@user.username}\r\n"
		@socket.write "USER #{@user.username} 0 * :Real Name\r\n"
		@socket.write 'JOIN #hadoop\r\n'
		# message order could not make sure here
		@isConnected = true
		@socket.write msg for msg in @msgBuf

	onClose: (data) =>
		console.log @user.username, 'connection close.'

	onReceiveRawMessage: (data) =>
		data = data.toString()
		if data.indexOf('PING') == 0
			@socket.write data.replace('PING :', 'PONG ')
		console.log 'Return by server:', data
		matchResult = @receiveMessageRegex.exec data
		if matchResult != null
			@onReceiveMessage matchResult[1], matchResult[2], matchResult[3]

	onTmpReceiveMessage: () ->
		Meteor.call 'sendMessage',
			u:
				username: 'haosdentd'
			to: 'haosdent'
			msg: 'reply'
			rid: 'EtomNKRwxp6mELsGGLHa4ybHScj2WZoo3K'

	onReceiveMessage: (name, target, content) ->
		console.log 'onReceiveMessage', this
		console.log '[irc] onReceiveMessage -> '.yellow, 'sourceUserName:', name, 'target:', target, 'content:', content
		# Meteor.call 'sendMessage',
		# 	u:
		# 		username: name
		# 	to: target
		# 	msg: content
		# 	rid: 'EtomNKRwxp6mELsGGLHa4ybHScj2WZoo3K'

	sendRawMessage: (msg) ->
		console.log '[irc] sendRawMessage -> '.yellow, msg
		if @isConnected
			@socket.write msg
		else
			@msgBuf.push msg

	sendMessage: (room, message) ->
		console.log '[irc] sendMessage -> '.yellow, 'userName:', message.u.username, 'arguments:', arguments
		target = ''
		if room.t == 'c'
			target = "##{room.name}"
		else if room.t == 'd'
			for name in room.usernames
				if message.u.username != name
					target = name
					break
		msg = "PRIVMSG #{target} :#{message.msg}\r\n"
		@sendRawMessage msg

	joinRoom: (room) ->
		msg = "JOIN ##{room.name}\r\n"
		@sendRawMessage msg

	leaveRoom: (room) ->
		msg = "PART ##{room.name}\r\n"
		@sendRawMessage msg


IrcClient.getByUid = (uid) ->
	return ircClientMap[uid]

IrcClient.create = (user) ->
	unless user._id of ircClientMap
		# new Irc user, onReceiveMessage
		new IrcClient user


class IrcLoginer
	constructor: (login) ->
		console.log '[irc] validateLogin -> '.yellow, login
		IrcClient.create login.user
		return login


class IrcSender
	constructor: (message) ->
		room = ChatRoom.findOne message.rid, { fields: { name: 1, usernames: 1, t: 1 } }
		ircClient = IrcClient.getByUid message.u._id
		ircClient.sendMessage room, message
		return message


class IrcRoomJoiner
	constructor: (user, room) ->
		ircClient = IrcClient.getByUid user._id
		ircClient.joinRoom room
		return room


class IrcRoomLeaver
	constructor: (user, room) ->
		ircClient = IrcClient.getByUid user._id
		ircClient.leaveRoom room
		return room


RocketChat.callbacks.add 'beforeValidateLogin', IrcLoginer, RocketChat.callbacks.priority.LOW
RocketChat.callbacks.add 'beforeSaveMessage', IrcSender, RocketChat.callbacks.priority.LOW
RocketChat.callbacks.add 'beforeJoinRoom', IrcSender, RocketChat.callbacks.priority.LOW
RocketChat.callbacks.add 'beforeLeaveRoom', IrcSender, RocketChat.callbacks.priority.LOW