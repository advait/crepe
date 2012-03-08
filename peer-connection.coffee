net = require('net')
gp = require('./gnutella-packet.js')

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables

# Parameters:
#   socket - The socket that will have it's handler set
#   context - An object that has the neighborhood, and other tables needed to route packets.
# Function:
#   Binds a supplied socket to a data handler
root.createSocketHandler = (socket, context) ->
  
  # Error handler
  socket.on 'error', (error) ->
    console.log "HANDLER Error: #{error}"

  # Incoming data handler
  socket.on 'data', (data) ->
    console.log "From buffer:"
    console.log data.toString()
    packet = gp.deserialize(data)
    switch packet.type

      # handle connect
      when gp.PacketType.CONNECT
        console.log "received CONNECT #{packet.ip}:#{packet.port}"
        # Add to neighborhood if it's a new neighbor
        if context.neighbors.ableToAdd(packet.ip, packet.port)
          connectOKPacket = new gp.ConnectOKPacket()
          try
            socket.write(connectOKPacket.serialize())
            context.neighbors.add(packet.ip, packet.port, socket)
          catch error
            console.log "sending CONNECTOK FAILED!"
        break

      # handle connect ok
      when gp.PacketType.CONNECTOK
        console.log "received CONNECTOK"
        if context.neighbors.ableToAdd(socket.remoteAddress, socket.remotePort)
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
        try
          socket.write(pong.serialize())
        catch error
          console.log "replying PONG FAILED!"
          context.neighbors.remove(socket.remoteAddress, socket.remotePort)

        # Forward ping to other neighbors
        packet.ttl--
        packet.hops++
        if context.forwarding[packet.id] == undefined && packet.ttl > 0
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
          try
            context.forwarding[packet.id].write(data)
          catch error
            console.log "Forwarding PONG FAILED!"
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
  
# Parameters:
#   address - The address of the destination peer (e.g. '127.0.0.1')
#   port - The port of the destination peer (e.g. '12345')
#   context - An object that contains the neighborhood and tables needed to route packets
# Function:
#   Creates a connection to the peer specified by address and port
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
    try
      socket.write(connectPacket.serialize())
    catch error
      console.log "Sending connect request FAILED!"

  console.log "hello socket: #{address}:#{port}"
  socket.connect(port, address)
