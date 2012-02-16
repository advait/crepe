###
# Crepe.coffee - Node.js Gnutella client
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen
#   Mark Vismonte
#
# Use netcat to send some of the included *.netcat files
###

net = require('net')
gp = require('./gnutella-packet.js')

p = new gp.PongPacket()
console.log p
console.log p.serialize()

# Crepe Gnutella server. Handles all incoming requests
crepeServer = new net.Server()


crepeServer.on 'listening', ->
  address = this.address()
  console.log "server is now listening on #{address.address}:#{address.port}"


# New connection handler
crepeServer.on 'connection', (socket) ->
  socket.setEncoding 'ascii'
  remote = "#{socket.remoteAddress}:#{socket.remotePort}"
  console.log "new connection from #{remote}"

  # Incoming data handler
  socket.on 'data', (data) ->
    if data == 'GNUTELLA CONNECT/0.4\n\n'
      socket.write 'GNUTELLA OK\n\n'

    else
      socket.end "Unknown command '#{data}'\n"
  
  # Connection close
  socket.on 'end', ->
    console.log "connection closed from #{remote}"


# Bind and run!
crepeServer.listen 1337
