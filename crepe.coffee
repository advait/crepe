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

shareFolder = process.cwd()

# Crepe Gnutella server. Handles all incoming requests
crepeServer = new net.Server()
fileServer = new FileServer(shareFolder)

# Run file server
fileServer.listen 0

# Bind a handler to initialize the listening server
crepeServer.on 'listening', ci.listeningHandler

# Bind a hanlder to handle new connections
crepeServer.on 'connection', ci.connectionHandler

# Bind and run!
crepeServer.listen 0, '0.0.0.0'

# Set fileServer port and share folder
ci.setFileServer fileServer
ci.setShareFolder shareFolder

# Set ci for REPL and start repl!
repl.setCrepeInternal ci
repl.start()
