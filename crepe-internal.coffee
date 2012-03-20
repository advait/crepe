###
# crepe-internal.coffee - This file handles all gnutella-specific internals
# and exposes a few useful methods as UI hooks
###

# Comment out this method to enable debug messages
#console.log = ->
#  return

# Imports
net = require('net')
fs = require('fs')
gp = require('./gnutella-packet.js')
assert = require('assert')
path = require('path')
shared_folder = process.cwd()

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables


################################################################################
# Internal data structures and related methods
################################################################################

# Internal tables used for routing
origin = {} # Stores {packet.id -> packet} mappings
mitm = {} # Stores {packet.id -> socket} mappings
query_hit = {} #Stores {packet.id -> callback} mappings

results = [] # An array of download objects

class DownloadObject
  constructor : (address, port, fileName) ->
    @address ?= address
    @port ?= port
    @fileName ?= fileName

# Address and port the server is listening on
serverAddress =
  address : '0.0.0.0'
  port : '0'

# Address and port the file server is listening on
fileServer =
  address : '0.0.0.0'
  port : '0'

root.setFSAddress = (address, port) ->
  fileServer.address = address
  fileServer.port = port

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
        if origin[packet.id]? && query_hit[packet.id]?
          query_hit[packet.id] packet
          #console.log "HITS: #{packet.address}:#{packet.port}"
          #for result in packet.resultSet
          #  result_string = "filename:#{result.fileName}, "
          #  result_string += "size:#{result.fileSize}, "
          #  result_string += "index:#{result.fileIndex}, "
          #  result_string += "serventID:#{packet.serventIdentifier}"
          #  console.log result_string

        else if mitm[packet.id]?
          console.log "forwarding QUERYHIT:#{packet.id}"
          try
            mitm[packet.id].write(data)
          catch error
            console.log "forwarding QUERHIT failed"
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
  q = new gp.QueryPacket()
  q.searchCriteria = query
  origin[q.id] = q
  query_hit[q.id] = (packet) ->
    console.log "HITS: #{packet.address}:#{packet.port}"
    for result in packet.resultSet
      result_string = "##{results.length} filename:#{result.fileName}, "
      result_string += "size:#{result.fileSize}, "
      result_string += "index:#{result.fileIndex}, "
      result_string += "serventID:#{packet.serventIdentifier}"
      results[results.length] = new DownloadObject(packet.address, packet.port, result.fileName)
      console.info result_string
  nh.sendToAll(q.serialize())

root.list = ->
  j = 0
  while j < results.length
    result = results[j]
    result_string = "##{j} filename:#{result.fileName}, "
    result_string += "address:#{result.address}, "
    result_string += "port:#{result.port}, "
    console.info result_string
    j++

# This method attempts to download the file identified by fileIdentifier
# Args:
#   fileIdentifier: a locally-unique identifier that uniquely identifies
#       a given QueryHit entry.
#   downloadStatusCallback: function - called periodically during the 
#       download process. (TODO: args)
root.download = (fileIdentifier, downloadStatusCallback) ->
  downItem = results[fileIdentifier]
  socket = new net.Socket()
  socket.on 'connect', ->
    console.info "Downloading: ##{fileIdentifier}:#{downItem.fileName}"
    try
      socket.write "GET /#{downItem.fileName}\n\n"
    catch error
      console.info "Failed to download file!"
  socket.on 'data', (data) ->
    console.info "#{data.toString()}"
  socket.connect(downItem.port, downItem.address)
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
            # TODO(Kevin): decide if we want to send ping or not. Might not want to add
            # another peer because we have reached the peer limit
            console.log "sending direct PING:#{ping.id} to #{socket.remoteAddress}:#{socket.remotePort}"

            #TODO: FIX THIS UGLY HACK
            # The data buffer on the other end of this socket queues up the CONNECTOK
            # and PING packets. This causes the packet to be misinterpreted.
            write_serialize = ->
              try
                socket.write(ping.serialize())
              catch error
                console.log "failed to send DIRECT PING"
            setTimeout(write_serialize, 2000)
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
        pong.address = socket.address().address
        pong.port = socket.address().port
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
        console.log "received PUSH:#{packet.id}"
        break

      # handle query
      when gp.PacketType.QUERY
        console.log "received QUERY:#{packet.id} search:#{packet.searchCriteria}"
        if origin[packet.id]? || mitm[packet.id]?
          console.log "drop QUERY because already seen"
          break

        # Forward query to all neighbors
        console.log "forwarding Query:#{packet.id}"
        mitm[packet.id] = socket
        nh.sendToAll(data)

        # Send a Query Hit if we find a match
        # TODO: use some globbing to find partial match instead of exact
        try
          stats = fs.statSync(path.join(shared_folder, packet.searchCriteria))
        catch error
          console.log "No Files matched:#{packet.searchCriteria}"
          break
        if stats.isFile()
          queryHit = new gp.QueryHitPacket()
          queryHit.address = fileServer.address
          queryHit.port = fileServer.port
          queryHit.id = packet.id
          queryHit.numHits = 2
          result = new Object()
          result.fileIndex = 1
          result.fileSize = stats.size
          result.fileName = packet.searchCriteria
          queryHit.addResult(result)

          # Test adding more than one result
          result = new Object()
          result.fileIndex = 1337
          result.fileSize = 13371337
          result.fileName = "FAKE DATA!"
          queryHit.addResult(result)

          console.log "sending QUERYHIT:#{packet.id}"
          try
            socket.write(queryHit.serialize())
          catch error
            console.log "Sending QUERYHIT failed: #{error}"
        else
          console.log "Can't send directory:#{packet.searchCriteria}"
        break

      # default
      else
        console.log "Unknown command:"
        console.log data

# This method sets up a listening port for the server as well as saving the
# address and port on which the server is listening.
root.listeningHandler = ->
  serverAddress = this.address()
  console.info "server is now listening on #{serverAddress.address}:#{serverAddress.port}"
  console.info "CTRL+C to exit"
  setInterval(updateNeighborhood, 10000)


################################################################################
# Neighborhood utility methods
################################################################################

# Neighborhood object to handle peers in the neighborhood set
nh =
  MAX_PEERS : 5
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
          console.log "PEER ERROR: #{error}"
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
