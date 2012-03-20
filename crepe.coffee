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
ci = require('./crepe-internal.js')
repl = require('./repl')
FileServer = require('./file-server').FileServer

shared_folder = process.cwd()

# Crepe Gnutella server. Handles all incoming requests
crepeServer = new net.Server()
fileServer = new FileServer(shared_folder)

# Run file server
fileServer.listen 0

ci.setFSAddress(fileServer.address(), fileServer.port())

# Bind a handler to initialize the listening server
crepeServer.on 'listening', ci.listeningHandler

# Bind a hanlder to handle new connections
crepeServer.on 'connection', ci.connectionHandler

# Bind and run!
crepeServer.listen 0, '0.0.0.0'

repl.setCrepeInternal ci
repl.start()

## Timer to keep probing network
#updateNeighborhood = ->
#  # Indicate that this node sent the original ping
#  ping = new gp.PingPacket()
#  context.origin[ping.id] = ping
#
#  # Flood neighbors with pings
#  console.log "periodic flood with ping:#{ping.id}"
#  context.neighbors.sendToAll(ping.serialize())
#setInterval(updateNeighborhood, 10000)
#
## Timer to keep printing list of neighbors
#printCurrentNeighborhood = ->
#  context.neighbors.printAll()
#setInterval(printCurrentNeighborhood, 10000)
