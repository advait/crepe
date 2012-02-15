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
  console.log "server is now listening on #{address.address}:#{address.port}"


# New connection handler
server.on 'connection', (socket) ->
  socket.setEncoding 'utf8'
  remote = "#{socket.remoteAddress}:#{socket.remotePort}"
  console.log "new connection from #{remote}"

  # Incoming data handler
  socket.on 'data', (data) ->
    data = data.trim()
    if data == 'ping'
      socket.write 'pong\r\n'
    else
      socket.write "unknown command '#{data}'\r\n"
  
  # Connection close
  socket.on 'end', ->
    console.log "connection closed from #{remote}"


# Bind and run!
server.listen 1337
