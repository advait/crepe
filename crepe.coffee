###
# Crepe.coffee - Node.js Gnutella client
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen (kevioke1337@gmail.com)
#   Mark Vismonte (mark.vismonte@gmail.com)
#
# Use netcat to send some of the included *.netcat files
###

# Imports
net = require('net')
fs = require('fs')
util = require('util')
gp = require('./gnutella-packet.js')
nh = require('./neighborhood.js')
pc = require('./peer-connection.js')
FileServer = require('./file-server').FileServer

bootstrap_host = process.argv[2]
bootstrap_port = process.argv[3]
shared_folder = process.cwd()

context = new Object()

# Origin table: stores the packets that originated from this node
# Key -> packet id
# Value -> packet
context.origin = {}

# Forwarding information table: A mapping from packet id to a return socket. 
# The return socket is used to route the response.
# Key -> packet id
# Value -> socket
context.forwarding = {}

# Neighborhood object handles all the neighbors
context.neighbors = new nh.Neighborhood()

# Crepe Gnutella server. Handles all incoming requests
crepeServer = new net.Server()
context.crepeServer = crepeServer
fileServer = new FileServer(shared_folder)

# Run file server
fileServer.listen 0

crepeServer.on 'listening', ->
  address = this.address()
  console.log "server is now listening on #{address.address}:#{address.port}"
  console.log "CTRL+C to exit"

# New connection handler
crepeServer.on 'connection', (socket) ->
  remote = "#{socket.remoteAddress}:#{socket.remotePort}"
  console.log "new connection from #{remote}"
  socket.setNoDelay()
  pc.createSocketHandler(socket, context)


# Bind and run!
crepeServer.listen 0, '127.0.0.1'

# connect to the bootstrap node
if bootstrap_port != undefined
  if bootstrap_host != undefined
    pc.createPeerConnection(bootstrap_host, bootstrap_port, context)
  else
    pc.createPeerConnection('127.0.0.1', bootstrap_port, context)

# Timer to keep probing network
updateNeighborhood = ->
  # Indicate that this node sent the original ping
  ping = new gp.PingPacket()
  context.origin[ping.id] = ping

  # Flood neighbors with pings
  console.log "periodic flood with ping:#{ping.id}"
  context.neighbors.sendToAll(ping.serialize())
setInterval(updateNeighborhood, 10000)

# Timer to keep printing list of neighbors
printCurrentNeighborhood = ->
  context.neighbors.printAll()
setInterval(printCurrentNeighborhood, 10000)
