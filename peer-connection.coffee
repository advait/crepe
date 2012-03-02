net = require('net')
gp = require('./gnutella-packet.js')

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables

# Generic socket handler for both server and client sockets
root.createSocketHandler = (socket, context) ->
  
  # Error handler
  socket.on 'error', (error) ->
    console.log "HANDLER Error: #{error}"

  # Incoming data handler
  socket.on 'data', (data) ->
    packet = gp.deserialize(data)
    switch packet.type

      # handle connect
      when gp.PacketType.CONNECT
        console.log "received CONNECT"
        # Add to neighborhood if it's a new neighbor
        if !context.neighbors.at(packet.ip, packet.port)
          context.neighbors.add(packet.ip, packet.port, socket)
          packet = new gp.ConnectOKPacket()
          socket.write(packet.serialize())
        break

      # handle connect ok
      when gp.PacketType.CONNECTOK
        console.log "received CONNECTOK"
        if !context.neighbors.at(socket.remoteAddress, socket.remotePort)
          context.neighbors.add(socket.remoteAddress, socket.remotePort, socket)
        break

      # handle ping
      when gp.PacketType.PING
        console.log "received PING:#{packet.id}"

        if context.origin[packet.id] || context.forwarding[packet.id]
          console.log "drop PING because already seen"
          break

        # Send pong in response to the ping
        console.log "replying PONG:#{packet.id} to #{@remoteAddress}:#{@remotePort}"
        serverAddress = context.crepeServer.address()
        pong = new gp.PongPacket()
        pong.id = packet.id
        pong.address = serverAddress.address
        pong.port = serverAddress.port
        pong.numFiles = 1337  # TODO(advait): Fix this
        pong.numKbShared = 1337  # TODO(advait): Fix
        socket.write(pong.serialize())

        # Forward ping to other neighbors
        if context.forwarding[packet.id] == undefined
          console.log "forwarding PING:#{packet.id} to all neighbors"
          context.forwarding[packet.id] = socket
          context.neighbors.sendToAll(data, socket)

      # handle pong
      when gp.PacketType.PONG
        console.log "received PONG:#{packet.id} #{packet.address}:#{packet.port}"
        # Try to initiate a new socket connection to the new peer
        if context.origin[packet.id] && !context.neighbors.at(packet.address, packet.port)
          console.log "Trying to connect to #{packet.address}:#{packet.port}"
          root.createPeerConnection(packet.address, packet.port, context)

        # Forward the pong back to where it originated
        else if context.forwarding[packet.id]
          console.log "Forwarding PONG:#{packet.id}"
          context.forwarding[packet.id].write(data)
        break

      # handle push
      when gp.PacketType.PUSH
        break

      # handle query
      when gp.PacketType.QUERY
        break

      # handle query hit
      when gp.PacketType.QUERYHIT
        break

      # default
      else
        console.log "Unknown command:"
        console.log data
  

# Creates an outgoing socket to a node specified at address:port. Context is an object containing
# the neighborhood, origin table, and forwarding table.
root.createPeerConnection = (address, port, context) ->
  socket = new net.Socket() 
  socket.setNoDelay()
  root.createSocketHandler(socket, context)

  socket.on 'connect', ->
    # Send connect request
    console.log "Sending connect request to #{socket.remoteAddress}:#{socket.remotePort}"
    connectPacket = new gp.ConnectPacket()
    serverAddress = context.crepeServer.address()
    connectPacket.ip = serverAddress.address
    connectPacket.port = serverAddress.port
    socket.write(connectPacket.serialize())

  socket.connect(port, address)
