###
# Crepe.coffee - Node.js Gnutella client
###

net = require('net')


###
# Simple ping/pong server.
# Telnet to localhost:1337 and send a 'ping'
# The server should reply with a 'pong'
###
server = new net.Server()


server.on 'listening', ->
  address = this.address()
  console.log 'server is now listening on ', address


# New connection handler
server.on 'connection', (socket) ->
  socket.setEncoding 'utf8'
  console.log 'new connection'

  # Incoming data handler
  socket.on 'data', (data) ->
    data = data.trim()
    if data == 'ping'
      socket.write 'pong\r\n'
    else
      socket.write "unknown command '#{data}'\r\n"


# Bind and run!
server.listen 1337
