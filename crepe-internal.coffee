###
# crepe-internal.coffee - This file handles all gnutella-specific internals
# and exposes a few useful methods as UI hooks
###

# Imports
net = require('net')
fs = require('fs')
util = require('util')
gp = require('./gnutella-packet.js')
nh = require('./neighborhood.js')
pc = require('./peer-connection.js')
FileServer = require('./file-server').FileServer


# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables


# This method attempts to add the address/port to our neighborhood.
# Args:
#   address: String - IP address
#   port: Number - port
root.connect: (address, port) ->
  assert.ok 1

# This method issues Query packets and calls resultCallback for every
# Query Hit packet it recieves
# Args:
#   query: String - the string to search for
#   resultCallback: function - called for every QueryHit packet
#     Args: 
#       queryHit - A QueryHit packet object representing the result
root.search: (query, resultCallback) ->
  assert.ok 1

# This method attempts to download the file identified by fileIdentifier
# Args:
#   fileIdentifier: a locally-unique identifier that uniquely identifies
#       a given QueryHit entry.
#   downloadStatusCallback: function - called periodically during the 
#       download process. (TODO: args)
root.download: (fileIdentifier, downloadStatusCallback) ->
  assert.ok 1
