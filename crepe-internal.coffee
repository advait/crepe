###
# crepe-internal.coffee - This file handles all gnutella-specific internals
# and exposes a few useful methods as UI hooks
###

# Imports
net = require('net')
fs = require('fs')
gp = require('./gnutella-packet.js')
FileServer = require('./file-server').FileServer


# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables


# Internal tables used for routing
origin = {} # Stores {packet.id -> packet} mappings
mitm = {} # Stores {packet.id -> socket} mappings


# Address and port the server is listening on
serverAddress =
  address : '0.0.0.0'
  port : '0'


################################################################################
# REPL API Methods
################################################################################


# This method attempts to add the address/port to our neighborhood.
# Args:
#   address: String - IP address
#   port: Number - port
root.connect = (address, port) ->
  if !port?
    port = address
    address = '127.0.0.1'

  socket = new net.Socket()
  socket.setNoDelay()

  # Error handler
  socket.on 'error', (error) ->
    console.log "CONNECT Error: #{error}"

  # Handle connection handshake
  socket.on 'connect', ->
    # Send connect request
    console.log "Sending CONNECT to #{socket.remoteAddress}:#{socket.remotePort}"
    connectPacket = new gp.ConnectPacket()
    try
      socket.write(connectPacket.serialize())
    catch error
      console.log "Sending connect request FAILED!"

  # Outgoing data handler for socket
  # Note: The outbound socket connections only handle the following packets
  #   - PONG
  #   - CONNECTOK
  #   - QUERYHIT
  #   - PING: special case because we want to add an immediate peer using this
  socket.on 'data', (data) ->
    console.log "Received Buffer:"
    console.log data
    packet = gp.deserialize(data)
    switch packet.type

      # handle connect ok
      when gp.PacketType.CONNECTOK
        console.log "received CONNECTOK #{socket.remoteAddress}:#{socket.remotePort}"
        if nh.ableToAdd(socket.remoteAddress, socket.remotePort)
          nh.add(socket.remoteAddress, socket.remotePort, socket)
        break

      # handle special direct ping from peer wanting to connect
      when gp.PacketType.PING
        console.log "received direct PING:#{packet.id} from #{socket.remoteAddress}:#{socket.remotePort}"

        # Send pong in response to the ping
        console.log "replying direct PONG:#{packet.id} to #{@remoteAddress}:#{@remotePort}"
        pong = new gp.PongPacket()
        pong.id = packet.id
        pong.address = serverAddress.address
        pong.port = serverAddress.port
        pong.ttl = 1
        try
          socket.write(pong.serialize())
        catch error
          console.log "replying direct PONG FAILED"
        break

      # handle pong
      when gp.PacketType.PONG
        console.log "received PONG:#{packet.id} from #{packet.address}:#{packet.port}"
        # Try to connect to peer if the pong is intended for this node
        # TODO: decide if we are able to add any more peers(Kevin)
        if origin[packet.id] && !nh.at(packet.address, packet.port) &&
              origin[packet.id].type == gp.PacketType.PING
          console.log "Trying to connect to #{packet.address}:#{packet.port}"
          root.connect(packet.address, packet.port)

        # Forward the pong back to where it originated
        else if mitm[packet.id]?
          console.log "Forwarding PONG:#{packet.id}"
          try
            mitm[packet.id].write(data)
          catch error
            console.log "Forwarding PONG FAILED!"
        break

      # handle query hit
      when gp.PacketType.QUERYHIT
        console.log "received QUERYHIT:#{packet.id}"
        #TODO: forward query hit
        break

      # default
      else
        console.log "Unknown command:"
        console.log data

  socket.connect(port, address)

# This method issues Query packets and calls resultCallback for every
# Query Hit packet it recieves
# Args:
#   query: String - the string to search for
#   resultCallback: function - called for every QueryHit packet
#     Args: 
#       queryHit - A QueryHit packet object representing the result
root.search = (query, resultCallback) ->
  assert.ok 1

# This method attempts to download the file identified by fileIdentifier
# Args:
#   fileIdentifier: a locally-unique identifier that uniquely identifies
#       a given QueryHit entry.
#   downloadStatusCallback: function - called periodically during the 
#       download process. (TODO: args)
root.download = (fileIdentifier, downloadStatusCallback) ->
  assert.ok 1


################################################################################
# Socket Handler Methods
################################################################################


# This method handles inbound sockets by classifying incoming packets and
# handling them accordingly.
# Args:
#   socket: The socket between this node and the incoming node
# Note: The inbound socket connections only handle the following packets
#   - PING
#   - CONNECT
#   - QUERY
#   - PONG: special case because we want to add an immediate peer using this
root.connectionHandler = (socket) ->

  # Error handler
  socket.on 'error', (error) ->
    console.log "HANDLER Error: #{error}"

  # Inbound data handler
  socket.on 'data', (data) ->
    console.log "Received Buffer:"
    console.log data
    packet = gp.deserialize(data)
    switch packet.type

      # handle connect
      when gp.PacketType.CONNECT
        console.log "received CONNECT from #{socket.remoteAddress}:#{socket.remotePort}"
        connectOKPacket = new gp.ConnectOKPacket()
        ping = new gp.PingPacket()
        ping.ttl = 1
        origin[ping.id] = ping
        try
          console.log "sending CONNECTOK to #{socket.remoteAddress}:#{socket.remotePort}"
          socket.write connectOKPacket.serialize(), 'binary', ->
            # TODO(Kevin): decide if we want to send ping or not
            console.log "sending direct PING:#{ping.id} to #{socket.remoteAddress}:#{socket.remotePort}"
            socket.write(ping.serialize())
        catch error
          console.log "sending CONNECTOK FAILED!"
        break

      # handle ping
      when gp.PacketType.PING
        console.log "received PING:#{packet.id}"

        if origin[packet.id]? || mitm[packet.id]?
          console.log "drop PING because already seen"
          break

        # Send pong in response to the ping
        console.log "replying PONG:#{packet.id} to #{@remoteAddress}:#{@remotePort}"
        pong = new gp.PongPacket()
        pong.id = packet.id
        pong.address = serverAddress.address
        pong.port = serverAddress.port
        pong.numFiles = 1337  # TODO(advait): Fix this
        pong.numKbShared = 1337  # TODO(advait): Fix
        try
          socket.write(pong.serialize())
        catch error
          console.log "replying PONG FAILED!"
          nh.remove(socket.remoteAddress, socket.remotePort)

        # Forward ping to other neighbors
        packet.ttl--
        packet.hops++
        if packet.ttl > 0
          console.log "forwarding PING:#{packet.id} to all neighbors"
          mitm[packet.id] = socket
          nh.sendToAll(data)
        break

      # handle special pong because immediate peer wants to connect
      when gp.PacketType.PONG
        console.log "received direct PONG:#{packet.id} #{packet.address}:#{packet.port}"
        if origin[packet.id]? && origin[packet.id].type == gp.PacketType.PING &&
            nh.ableToAdd(packet.address, packet.port) && packet.ttl == 1 && packet.hops == 0
          root.connect(packet.address, packet.port)
        break

      # handle push
      when gp.PacketType.PUSH
        break

      # handle query
      when gp.PacketType.QUERY
        break

      # default
      else
        console.log "Unknown command:"
        console.log data

# This method sets up a listening port for the server as well as saving the
# address and port on which the server is listening.
root.listeningHandler = ->
  serverAddress = this.address()
  console.log "server is now listening on #{serverAddress.address}:#{serverAddress.port}"
  console.log "CTRL+C to exit"
  setInterval(updateNeighborhood, 10000)


################################################################################
# Neighborhood utility methods
################################################################################

# Neighborhood object to handle peers in the neighborhood set
nh =
  MAX_PEERS : 2
  neighbors : {}
  count : 0

  # Add new peer to the neighborhood set
  add: (ip, port, socket) ->
    if @count < @MAX_PEERS
      console.log "Added new peer #{ip}:#{port}"
      @neighbors["#{ip}:#{port}"] = socket
      @count++

  # Remove peer from the neighborhood set
  remove: (ip, port) ->
    if @neighbors["#{ip}:#{port}"]
      @neighbors["#{ip}:#{port}"] = undefined
      @count--

  # Return the socket associated with the peer at ip and port
  at: (ip, port) ->
    return @neighbors["#{ip}:#{port}"]

  # Return true if a new peer can be added to the neighborhood
  ableToAdd: (ip, port) ->
    if !@at(ip, port)? && @count < @MAX_PEERS
      return true
    else
      return false

  # Send data to all peers in the neighborhood but do not send to the peer
  # associated with the "exclude" socket. The "exclude" paramter is used to exclude
  # the peer that sent the incoming ping or query.
  sendToAll: (data) ->
    for node, socket of @neighbors
      # ignore the excluded socket and undefined sockets
      if socket?
        try
          socket.write data
        catch error
          console.log "peer #{node} died. Removing #{node}"
          @neighbors[node] = undefined
          @count--

  # Print the list of neighbors
  printAll: ->
    console.log "List of neighbors:"
    for node, socket of @neighbors
      if socket?
        console.log "#{node}"

updateNeighborhood = ->
  # Indicate that this node sent the original ping
  ping = new gp.PingPacket()
  origin[ping.id] = ping

  # Flood neighbors with pings
  console.log "Flood neighbors with ping:#{ping.id}"
  nh.printAll()
  nh.sendToAll(ping.serialize())
