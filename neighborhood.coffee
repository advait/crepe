gp = require('./gnutella-packet.js')
# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables

# Neighborhood class to handle peers in the neighborhood set
class root.Neighborhood

  # Initialize set of neighbors and count. Neighbors is an array of sockets to all
  # the neighbor nodes.
  constructor: ->
    @neighbors = {}
    @count = 0

  # Add new peer to the neighborhood set
  add: (ip, port, socket) ->
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

  # Send data to all peers in the neighborhood but do not send to the peer
  # associated with the "exclude" socket. The "exclude" paramter is used to exclude
  # the peer that sent the incoming ping or query.
  sendToAll: (data, exclude) ->
    for node, socket of @neighbors
      # ignore the excluded socket and undefined sockets
      if socket != exclude && socket != undefined
        try
          socket.write data
        catch error
          console.log "peer #{node} died. Removing #{node}"
          @neighbors[node] = undefined

  # Print the list of neighbors
  printAll: ->
    console.log "List of neighbors:"
    for node, socket of @neighbors
      if socket != undefined
        console.log "#{node}"
