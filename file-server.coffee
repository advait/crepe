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
  shareFolder: '///'  # The folder we're going to share

  constructor: (shareFolder) ->
    @shareFolder = shareFolder

    # Create an HTTP server with the following callback.
    @server =  http.createServer (request, response) ->
      # Lookup the file and prepend the folder path.
      file = decodeURIComponent url.parse(request.url).pathname
      fileName = path.join(shareFolder, path.normalize(file))
      validFile = (fileName.indexOf(shareFolder) == 0)
      console.log "fileName: #{file}"

      if request.method == "GET"
        console.log "User downloading file: #{fileName}"

        # Send the file back if it exists, or return if there's an error.
        path.exists fileName, (exists) ->
          if (!exists or !validFile)
            response.writeHead 404, {"Content-Type": "text/plain" }
            response.write "404 Not Found\n"
            response.end()
            return

          fs.readFile fileName, "binary", (err, file) ->
            if(err)
              response.writeHead 500, {"Content-Type": "text/plain"}
              response.write "#{err}\n"
              response.end()
              return

            response.writeHead 200
            response.write file, "binary"
            response.end()
      else if request.method == "PUT"
        # You can test uploading files using:
        # curl --upload-file <local_file_path> 
        #   http://<server_ip>:<port>/<upload_file_name>
        console.log "User uploading file: #{fileName}"
        buf = new Buffer(1024)

        request.setEncoding "binary"

        request.on "data", (data) ->
          # console.log data.toString()
          buf += data

        request.on "end", ->
          fs.writeFile fileName, buf, "binary", (err) ->
            # Throw 500 on any errors. Otherwise, 200 is fine.
            if err
              response.writeHead 500
              response.write "#{err}\n"
              response.end()
            else
              response.writeHead 200
              response.write "Saved File success!\n"
              response.end()
              console.log "Saved File success!"

  listen: (port) ->
    @server.listen port
    console.info "Static Files hosting on localhost:#{@server.address().port}"

  address: ->
    return @server.address().address

  port: ->
    return @server.address().port

  # This method searches the shareFolder directory according to the query
  # and returns an array of all files found.
  # Args:
  #   query: String the query used to search
  # Returns:
  #   Array of objects with the attributes:
  #     fileIndex: Integer the index of this file
  #     fileSize: Integer the size of this file in bytes
  #     fileName: String the fileName of this file
  search: (query) ->
    console.log "Searching for query '#{query}'"

    # Naive direct filename matching
    fileName = path.join(@shareFolder, path.normalize(query))
    validFile = (fileName.indexOf(@shareFolder) == 0)
    try
      console.log "Statting #{fileName}"
      if !validFile  # Someone tried to escape out of this directory
        throw "Trying to escape from shared folder"

      stats = fs.statSync(fileName)
      if !stats.isFile()
        throw "Not a file"

      output = []
      output.push {
        fileIndex: stats.ino  # Use the inode number for the fileIndex
        fileSize: stats.size
        fileName: query
      }

      return output
    catch error
      console.log error
      return []
