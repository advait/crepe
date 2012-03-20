###
# gnutella-packet.coffee - basic classes for Gnutella packets
#
# These classes provide a clean interface to read/write low-level Gnutella
# packets. The deserialize() method takes in a buffer and returns a
# GnutellaPacket subclass. The GnutellaPacket.serialize() method generates
# a sendable buffer
###

assert = require('assert')

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables

# This method returns a random 16 byte string
randomString = ->
  charSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  result = ''
  for i in [0..15]
    randomPoz = Math.floor(Math.random() * charSet.length)
    result += charSet.substring(randomPoz,randomPoz+1)
  return result

root.randomString = randomString

##############################################################################
# Deserialize
##############################################################################


# deserialize a raw data buffer into a GnutellaPacket subclass
# This method is pretty vital!
# Args:
#   buffer: The incoming buffer to deserialize.
# Returns:
#   A GnutellaPacket subclass corresponding to the type of packet we got.
root.deserialize = (buffer) ->
  assert.ok Buffer.isBuffer buffer
  s = buffer.toString()

  if s == 'GNUTELLA CONNECT/0.4\n\n'
    return new root.ConnectPacket(buffer)

  if s == 'GNUTELLA OK\n\n'
    return new root.ConnectOKPacket()

  assert.ok buffer.length >= root.GnutellaPacket::HEADER_SIZE
  payloadDescriptor = buffer[16]  # see spec!

  output = null
  payloadBuffer = buffer.slice(root.GnutellaPacket::HEADER_SIZE)
  switch payloadDescriptor
    when 0x00 then output = new root.PingPacket(payloadBuffer)
    when 0x01 then output = new root.PongPacket(payloadBuffer)
    when 0x40 then output = new root.PushPacket(payloadBuffer)
    when 0x80 then output = new root.QueryPacket(payloadBuffer)
    when 0x81 then output = new root.QueryHitPacket(payloadBuffer)
    else throw 'Invalid/corrupt packet'

  # Parse packet header
  output.id = buffer.toString('utf8', 0, 16)
  output.ttl = buffer[17]
  output.hops = buffer[18]

  return output

##############################################################################
# GnutellaPacket implementations
##############################################################################


# Enum: The types of packets we have!
PacketType =
  CONNECT: 1
  CONNECTOK: 2
  PING: 3
  PONG: 4
  QUERY: 5
  QUERYHIT: 6
  PUSH: 7
  CORRUPT: -1

root.PacketType = PacketType


# Gnutella Packet base class
class root.GnutellaPacket
  HEADER_SIZE: 23  # The size of the packet header

  # Serializes this packet object into a sendable buffer
  # Args:
  #   payload: a buffer containing a Gnutalla Payload
  # Returns:
  #   A buffer of sendable data
  serialize: (payload) ->
    # The simple packet types
    if @type == PacketType.CONNECT
      return new Buffer('GNUTELLA CONNECT/0.4\n\n')
    if @type == PacketType.CONNECTOK
      return new Buffer('GNUTELLA OK\n\n')

    # Instantiation sanity checks
    assert.ok Buffer.isBuffer(payload)
    assert.ok typeof(@id) == 'string' and @id.length == 16
    assert.ok typeof(@ttl) == 'number'
    assert.ok typeof(@hops) == 'number'

    # The final Buffer we're going to output
    output = new Buffer(@HEADER_SIZE + payload.length)
    
    # set Message ID
    output.write @id, 0, 'ascii'

    # set Payload Descriptor
    output[16] = switch @type
      when PacketType.PING then 0x00
      when PacketType.PONG then 0x01
      when PacketType.PUSH then 0x40
      when PacketType.QUERY then 0x80
      when PacketType.QUERYHIT then 0x81
      else throw 'Invalid/corrupt packet'

    output[17] = @ttl  # set TTL
    output[18] = @hops # set hops

    # set Payload Length
    output.writeUInt32BE(payload.length, 19)

    # set actual Payload
    payload.copy(output, @HEADER_SIZE)

    return output

    
  # See the Gnutella Spec:  http://www.stanford.edu/class/cs244b/gnutella_protocol_0.4.pdf
  id: null  # String Gnutella Packet ID
  type: null  # PacketType representing packet type
  ttl: null  # Integer TTL
  hops: null  # Integer Hops


# A Gnutella Connect packet
class root.ConnectPacket extends root.GnutellaPacket
  constructor: (data) ->
    @type = PacketType.CONNECT

  serialize: ->
    return new Buffer("GNUTELLA CONNECT/0.4\n\n", 'ascii')
    

# A Gnutella Connect OK packet
class root.ConnectOKPacket extends root.GnutellaPacket
  constructor: (data) ->
    @type = PacketType.CONNECTOK

  serialize: -> new Buffer 'GNUTELLA OK\n\n', 'ascii'


# A Gnutella Ping Packet
class root.PingPacket extends root.GnutellaPacket
  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  #       luckily, PingPacket don't have payloads so this should be an
  #       empty buffer
  constructor: (data) ->
    @type = PacketType.PING
    if Buffer.isBuffer(data)
      assert.ok data.length == 0
    # Note: Ping Packets don't have any ping-specific attributes
    #@id ?= "2222222222222222"
    @id ?= randomString()
    @ttl ?= 7
    @hops ?= 0

  serialize: ->
    super new Buffer(0)


# A Gnutella Pong Packet
class root.PongPacket extends root.GnutellaPacket
  PAYLOAD_SIZE: 14

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  constructor: (data) ->
    @type = PacketType.PONG
    if Buffer.isBuffer(data)
      # extract the pong information from the payload (i.e. the pong descriptor)
      #assert.ok data.length == @PAYLOAD_SIZE
      @port = data.readUInt16BE(0)
      @address = littleEndianToIp(data.slice(2, 6))
      @numFiles = data.readUInt32BE(6)
      @numKbShared = data.readUInt32BE(10)
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      #@id ?= "2222222222222222"
      @id ?= randomString()
      @ttl ?= 7
      @hops ?= 0
      @port ?= 0
      @address ?= "137.137.137.137"
      @numFiles ?= 0
      @numKbShared ?= 0

  serialize: ->
    payload = new Buffer(@PAYLOAD_SIZE)
    payload.writeUInt16BE(@port, 0)
    ipToLittleEndian(@address, 4).copy(payload, 2)
    payload.writeUInt32BE(@numFiles, 6)
    payload.writeUInt32BE(@numKbShared, 10)
    super payload


# A Gnutella Query Packet
class root.QueryPacket extends root.GnutellaPacket
  MIN_PAYLOAD_SIZE: 2

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  constructor: (data) ->
    @type = PacketType.QUERY
    if Buffer.isBuffer(data)
      # extract the pong information from the payload (i.e. the pong descriptor)
      assert.ok data.length >= @MIN_PAYLOAD_SIZE
      @speed = data.readUInt16BE(0)
      @searchCriteria = data.toString('utf8', 2, data.length - 1)
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      @id ?= randomString()
      @ttl ?= 7
      @hops ?= 0
      @searchCriteria ?= 'hello world'
      @speed ?= 1337

  serialize: ->
    payload = new Buffer(@searchCriteria.length + 3)
    payload.writeUInt16BE(@speed, 0)
    payload.write(@searchCriteria, 2)
    payload[payload.length - 1] = 0  # Null terminator
    super payload


# A Gnutella Query Hit Packet
class root.QueryHitPacket extends root.GnutellaPacket
  MIN_PAYLOAD_SIZE: 11
  MIN_RESULT_SIZE: 9

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  #       luckily, PingPacket don't have payloads so this should be an
  #       empty buffer
  constructor: (data) ->
    @type = PacketType.QUERYHIT
    if Buffer.isBuffer(data)
      assert.ok data.length >= @MIN_PAYLOAD_SIZE
      @numHits = data[0]
      @port = data.readUInt16BE(1)
      @address = bigEndianToIp(data.slice(3, 7))
      @speed = data.readUInt32BE(7)

      console.log "Deserializing QH Step 1: ", this

      # Parse each result
      @resultSet = []
      data = data.slice(@MIN_PAYLOAD_SIZE)
      console.log "numHits: ", @numHits
      iterator = if @numHits > 0 then [1..@numHits] else []
      for i in iterator
        console.log data
        assert.ok data.length >= @MIN_RESULT_SIZE
        result = new Object()
        result.fileIndex = data.readUInt32BE(0)
        result.fileSize = data.readUInt32BE(4)
        j = 0
        while data[8+j] != 0
          j++
        result.fileName = data.slice(8, 8+j).toString()
        @resultSet.push(result)
        data = data.slice(8+j+2)

      assert.ok data.length == 16
      @serventIdentifier = data.toString('ascii', 0, 16)
    else
      # Set default attributes
      @id = randomString()
      @ttl = 7
      @hops = 0
      @numHits = 0
      @port = 0
      @address = '0.0.0.0'
      @speed = 0
      @resultSet = []
      @serventIdentifier = '0123456789abcdef'

  serialize: ->
    header = new Buffer(@MIN_PAYLOAD_SIZE)
    header.writeUInt8(@numHits, 0)
    header.writeUInt16BE(@port, 1)
    addressBuffer = ipToBigEndian(@address)
    addressBuffer.copy(header, 3)
    header.writeUInt32BE(@speed, 7)

    # Parse each result
    resultBuffers = []
    totalResultBuffersLength = 0
    for result in @resultSet
      resultLength = 4 + 4 + result.fileName.length + 2
      resultBuffer = new Buffer(resultLength)
      resultBuffer.writeUInt32BE(result.fileIndex, 0)
      resultBuffer.writeUInt32BE(result.fileSize, 4)
      resultBuffer.write(result.fileName, 8)
      resultBuffer.writeUInt16BE(0x0000, resultLength-2)  # Null Bytes
      resultBuffers.push(resultBuffer)
      totalResultBuffersLength += resultBuffer.length

    # Create final output buffer (16 bytes for the servent identifier)
    totalLength = header.length + totalResultBuffersLength + 16
    payload = new Buffer(totalLength)
    header.copy(payload, 0)
    currentIndex = @MIN_PAYLOAD_SIZE
    for b in resultBuffers
      b.copy(payload, currentIndex)
      currentIndex += b.length

    payload.write(@serventIdentifier, currentIndex, 16, 'utf8')
    super payload

  # Adds a result to this packet
  # Args:
  #   resultObject: A simple object with three key/values:
  #       fileIndex: Integer uniquely identifying the file
  #       fileSize: Integer file size in bytes
  #       fileName: String of the file name
  addResult: (resultObject) ->
    assert.ok resultObject.fileIndex?
    assert.ok resultObject.fileSize?
    assert.ok resultObject.fileName?
    @numHits++
    @resultSet.push resultObject


# A Gnutella Push Packet
class root.PushPacket extends root.GnutellaPacket
  PAYLOAD_SIZE: 26

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  constructor: (data) ->
    @type = PacketType.PUSH
    if Buffer.isBuffer(data)
      assert.ok data.length == @PAYLOAD_SIZE
      @serventIdentifier = data.toString('utf8', 0, 16)
      @fileIndex = data.readUInt32BE(16)
      @address = bigEndianToIp(data.slice(20, 24))
      @port = data.readUInt16BE(24)
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      @id ?= "8888888888888888"
      @ttl ?= 7
      @hops ?= 0
      @serventIdentifier ?= '0123456789abcdef'
      @fileIndex ?= 1337
      @address ?= '137.137.137.137'
      @port ?= 0

  serialize: ->
    payload = new Buffer(@PAYLOAD_SIZE)
    payload.write(@serventIdentifier, 0, 16)
    payload.writeUInt32BE(@fileIndex, 16)
    ipToBigEndian(@address).copy(payload, 20)
    payload.writeUInt16BE(@port, 24)
    super payload

##############################################################################
# Utility methods
##############################################################################


# Converts an ip address (string) into a Big Endian byte buffer
ipToBigEndian = (ip) ->
  ip = ip.split('.')
  assert.ok ip.length == 4
  output = new Buffer 4
  for i in [0..3]
    output[i] = parseInt ip[i]
  return output
root.ipToBigEndian = ipToBigEndian


# Converts an ip address (string) into a Little Endian byte buffer
ipToLittleEndian = (ip) ->
  ip = ip.split('.')
  assert.ok ip.length == 4
  output = new Buffer 4
  for i in [0..3]
    output[i] = parseInt ip[3-i]
  return output
root.ipToLittleEndian = ipToLittleEndian

# Converts a Big Endian byte buffer to an ip address (string)
bigEndianToIp = (buffer) ->
  assert.ok buffer.length == 4
  "#{buffer[0]}.#{buffer[1]}.#{buffer[2]}.#{buffer[3]}"

# Converts a Little Endian byte buffer to an ip address (string)
littleEndianToIp = (buffer) ->
  assert.ok buffer.length == 4
  "#{buffer[3]}.#{buffer[2]}.#{buffer[1]}.#{buffer[0]}"

