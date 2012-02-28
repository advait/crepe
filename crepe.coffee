###
# Crepe.coffee - Node.js Gnutella client
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen (kevioke1337@gmail.com)
#   Mark Vismonte
#
# Use netcat to send some of the included *.netcat files
###

# Imports
net = require('net')
fs = require('fs')
util = require('util')
gp = require('./gnutella-packet.js')


bootstrap_port = process.argv[2]
bootstrap_host = process.argv[3]
nodes = new Object()
shared_folder = "shared"


# Crepe Gnutella server. Handles all incoming requests
crepeServer = new net.Server()


crepeServer.on 'listening', ->
  address = this.address()
  console.log "server is now listening on #{address.address}:#{address.port}"


# New connection handler
crepeServer.on 'connection', (socket) ->
  remote = "#{socket.remoteAddress}:#{socket.remotePort}"
  console.log "new connection from #{remote}"

  # Incoming data handler
  socket.on 'data', (data) ->
    packet = gp.deserialize(data)
    switch packet.type
      # handle ping
      when gp.PacketType.PING
        # store node in array of neighbor nodes
        nodes[this.remoteAddress + ":" + this.remotePort] = true

        # DEBUG output
        for address of nodes
          console.log "Neighbor #{address}"

        # send pong
        console.log "sending pong to #{@remoteAddress}:#{@remotePort}"
        serverAddress = crepeServer.address()
        pong = new gp.PongPacket()
        pong.address = serverAddress.address
        pong.port = serverAddress.port
        pong.numFiles = 1337  # TODO(advait): Fix this
        pong.numKbShared = 1337  # TODO(advait): Fix
        socket.write(pong.serialize())

        #TODO: forward ping to other nodes

      # handle pong
      when gp.PacketType.PONG
        break

      # handle push
      when gp.PacketType.PONG
        break

      # handle query
      when gp.PacketType.PONG
        break

      # handle query hit
      when gp.PacketType.PONG
        break

      # default
      else
        socket.write "Unknown command '#{data}'\n"
  
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

# crepeConnect socket handles joining the network
crepeConnect = new net.Socket()

crepeConnect.on 'connect', ->
  # Send connect request
  console.log "Sending connect request to #{this.remoteAddress}:#{this.remotePort}"
  conPacket = new gp.ConnectPacket()
  this.write(conPacket.serialize())

# Error handler
crepeConnect.on 'error', (error) ->
  console.log "Error: #{error}"

# Incoming data
crepeConnect.on 'data', (data) ->

  # Handle Connect OK confirmation
  if data.toString() == 'GNUTELLA OK\n\n'
    console.log "Received ok from #{this.remoteAddress}:#{this.remotePort}"
    console.log "Sending ping message to #{this.remoteAddress}:#{this.remotePort}"

    # Send a ping to the bootstrap node
    ping = new gp.PingPacket()
    this.write(ping.serialize())

  # Handle incoming pong
  else if data[16] == 0x01
    pong = new gp.PongPacket(data)
    console.log "Received pong from #{pong.address}:#{pong.port}"
    console.log "#{pong.address}:#{pong.port} has #{pong.numFiles} files, #{pong.numKbShared} Kb"

  else
    console.log "UNKNOWN data: #{data.toString()}"

# connect to the bootstrap node
if bootstrap_port != undefined
  if bootstrap_host != undefined
    crepeConnect.connect(bootstrap_port, bootstrap_host)
  else
    crepeConnect.connect(bootstrap_port)
