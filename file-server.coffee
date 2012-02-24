###
# file-server.coffee - Node.js file-server
# Authors:
#   Advait Shinde (advait.shinde@gmail.com)
#   Kevin Nguyen (kevioke1337@gmail.com)
#   Mark Vismonte (mark.vismonte@gmail.com)
#
# Create an http server to host files
###

# Imports
http = require("http")
url = require("url")
path = require("path")
fs = require("fs")

# Static File server class wrapped around an HTTP server
class exports.FileServer
  constructor: (shareFolder) ->
    # Create an HTTP server with the following callback.
    @server =  http.createServer (request, response) ->

      # Lookup the file and prepend the folder path.
      file = decodeURIComponent url.parse(request.url).pathname
      filename = path.join(shareFolder, file)
      console.log "Filename: #{file}"
      console.log "Filepath: #{filename}"

      # Send the file back if it exists, or return if there's an error.
      path.exists filename, (exists) ->
        if (!exists)
          response.writeHead 404, {"Content-Type": "text/plain" }
          response.write "404 Not Found\n"
          response.end()
          return

        fs.readFile filename, "binary", (err, file) ->
          if(err)     
            response.writeHead 500, {"Content-Type": "text/plain"}
            response.write "#{err}\n"
            response.end()
            return

          response.writeHead 200
          response.write file, "binary"
          response.end()

  listen: (port) ->
    @server.listen port
    console.log "Static Files hosting on localhost:7777\nCTRL+C to exit"
