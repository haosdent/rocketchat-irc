net = Npm.require('net')

ircMap = {}

class Irc
	constructor: (@user, @onReceiveMessage) ->
		ircMap[@user._id] = this
		port = 6667
		host = 'irc.freenode.net'
		@msgBuf = []
		@isConnected = false
		@socket = new net.Socket
		@socket.setNoDelay
		@socket.setEncoding 'utf-8'
		@socket.connect port, host, @onConnect
		@socket.on 'data', @onData
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

	onData: (data) =>
		data = data.toString()
		if data.indexOf('PING') == 0
			@socket.write data.replace('PING :', 'PONG ')
		#console.log 'Return by server:', data
		matchResult = @receiveMessageRegex.exec data
		if matchResult != null
			@receiveMessage matchResult[1], matchResult[2], matchResult[3]

	onClose: (data) =>
		console.log @user.username, 'connection close.'

	sendRawMessage: (msg) ->
		if @isConnected
			@socket.write msg
		else
			@msgBuf.push msg

	sendMessage: (message) ->
		msg = "PRIVMSG haosdent :#{message.msg}\r\n"
		@sendRawMessage msg
		message.uid = @user._id
		@onReceiveMessage message

	receiveMessage: (name, target, content) ->
		message = {
			username: name,
			roomname: 'test_one',
			msg: content
		}
		@onReceiveMessage message

	joinRoom: (room) ->
		msg = "JOIN ##{room.name}\r\n"
		console.log msg
		@sendRawMessage msg


Irc.getByUid = (uid) ->
	return ircMap[uid]

Irc.create = (user, onReceiveMessage) ->
	unless user._id of ircMap
		new Irc user, onReceiveMessage