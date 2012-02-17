###
# Crepe.coffee - Node.js Gnutella client
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen
#   Mark Vismonte
#
# Use netcat to send some of the included *.netcat files
###

bootstrap_port = process.argv[2]
bootstrap_host = process.argv[3]

net = require('net')
gp = require('./gnutella-packet.js')

p = new gp.PingPacket()
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

  # Socket error
  socket.on 'error', (error) ->
    console.log "SOCKET ERROR: #{error}"
    if error.code == 'EADDRINUSE'
      console.log "retrying with different port"


# Bind and run!
crepeServer.listen 0

# Connect to bootstrap node and try to join network
crepeConnect = new net.Socket()
crepeConnect.on 'connect', ->
  this.write('GNUTELLA CONNECT/0.4\n\n')

# Error handler
crepeConnect.on 'error', (error) ->
  console.log "Error: #{error}"

# Incoming data
crepeConnect.on 'data', (data) ->
  console.log data.toString('ascii')
  if data.toString('ascii') == 'GNUTELLA OK\n\n'
    console.log "Successfully connected to #{this.remotePort}"

# Try to contact bootstrap node
if bootstrap_port != undefined
  if bootstrap_host != undefined
    crepeConnect.connect(bootstrap_port, bootstrap_host)
  else
    crepeConnect.connect(bootstrap_port)
