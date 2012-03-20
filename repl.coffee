###
# repl.coffee - Node.js file-server
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen (kevioke1337@gmail.com)
#   Mark Vismonte (mark.vismonte@gmail.com)
#
# Create a REPL
###

# Imports
repl = require('repl')

# globals
ci = null

eval = (cmd) ->
  # Remove parathesis and use regex to parse into list.
  cmd = cmd.slice 1, cmd.length - 1
  tokens = cmd.match /\S+/g

  console.log tokens

  switch (tokens[0])
    when "connect"
      if (not tokens[1])
        console.log "Error: IP Address or port must be defined"
        return

      # Call connect in crepe-internal
      ci.connect tokens[1], tokens[2]

    when "download"
      if (not tokens[1])
        console.log "Error: File ID must be entered"
        return

      # Call download in crepe-internal
      ci.download tokens[1]

    when "search"
      if (not tokens[1])
        console.log "Error: Search term must be defined"
        return

      # Call search in crepe-internal
      ci.search tokens[1]

    when "list"
      # Call list in crepe-internal
      ci.list()

    when "neighbors"
      # Print for neighbors.
      ci.printNeighbors()

    when "help"
      console.log "\n
        List of commands:\n
        connect <ip_address> <port>\n
        search <search_term>\n
        list\n
        neighbors\n
        download <file_id>\n
      "
    else
      console.log "Error! no command \"#{tokens[0]}\""
  

# Global methods.

# Starts the REPL
exports.start = ->
  repl.start 'crepe>> ', null, eval
  
# Setter for new CI
exports.setCrepeInternal = (newCI) ->
  ci = newCI