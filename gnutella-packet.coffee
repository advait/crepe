###
# gnutella-packet.coffee - basic classes for Gnutella packets
###

assert = require('assert')

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables


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
  assert.ok buffer.isBuffer buffer
  s = buffer.toString()

  if s == 'GNUTELLA CONNECT/0.4\n\n'
    return new root.ConnectPacket()

  if s == 'GNUTELLA OK\n\n'
    return new root.ConnectOKPacket()

  assert.ok buffer.length >= root.GnutellaPacket.HEADER_SIZE
  payloadDescriptor = buffer[16]  # see spec!

  output = null
  payloadBuffer = buffer.slice(root.GnutellaPacket.HEADER_SIZE)
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
    assert.ok payload instanceof Buffer
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
    payloadLengthBuffer = numberToBuffer payload.length, 4
    payloadLengthBuffer.copy output, @HEADER_SIZE-4

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

  serialize: -> new Buffer 'GNUTELLA CONNECT/0.4\n\n', 'ascii'
    

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

  serialize: ->
    super new Buffer(0)


# A Gnutella Pong Packet
class root.PongPacket extends root.GnutellaPacket
  PAYLOAD_SIZE: 14

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  constructor: (data) ->
    @type = PacketType.PONG
    if data instanceof Buffer
      # extract the pong information from the payload (i.e. the pong descriptor)
      assert.ok data.length == @PAYLOAD_SIZE
      @port = bufferToNumber(data.slice(0, 2))
      @address = littleEndianToIp(data.slice(2, 6))
      @numFiles = bufferToNumber(data.slice(6, 10))
      @numKbShared = bufferToNumber(data.slice(10, 14))
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      @id ?= "8888888888888888"
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
    if data instanceof Buffer
      # extract the pong information from the payload (i.e. the pong descriptor)
      assert.ok data.length >= @MIN_PAYLOAD_SIZE
      @searchCriteria = data.toString('utf8', 2)
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      @id ?= "8888888888888888"
      @ttl ?= 7
      @hops ?= 0
      @searchCriteria ?= 'hello world'

  serialize: ->
    payload = new Buffer(@searchCriteria.length + 1)
    payload.write(@searchCriteria)
    payload[@searchCriteria] = 0  # Null terminator
    super payload


# A Gnutella Query Hit Packet
class root.QueryHitPacket extends root.GnutellaPacket
  MIN_PAYLOAD_SIZE: 11
  # TODO(advait): Implement this


# A Gnutella Push Packet
class root.PushPacket extends root.GnutellaPacket
  PAYLOAD_SIZE: 26

  # Args:
  #   data: (optional) A Gnutella payload buffer (without the header)
  constructor: (data) ->
    @type = PacketType.PUSH
    if data instanceof Buffer
      assert.ok data.length == @PAYLOAD_SIZE
      @serventIdentifier = data.toString('utf8', 0, 16)
      @fileIndex = bufferToNumber(data.slice(16, 20))
      @address = bigEndianToIp(data.slice(20, 24))
      @port = bufferToNumber(data.slice(24, 26))
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
    payload = new Buffer(PAYLOAD_SIZE)
    payload.write(@serventIdentifier, 0, 16)
    payload.writeUInt32BE(@fileIndex, 16)
    ipToBigEndian(@address).copy(payload, 20)
    payload.writeUInt16BE(@port, 24)
    super payload

##############################################################################
# Utility methods
##############################################################################


# TODO(advait): Deprecate all these methods in favor of the inbuilt ones:
# http://nodejs.org/docs/latest/api/buffers.html#buffer.readInt32LE


# Converts a JS number n into a Big Endian integer buffer
# Args:
#   n: the number to convert (floored to an Integer)
#   bufferSize: the number of bytes in the output buffer (default = 4)
# Returns:
#   A Buffer of size bufferSize that is the big endian integer representation
#   of n.
numberToBuffer = (n, bufferSize) ->
  n = Math.floor n
  bufferSize ?= 4
  b = new Buffer bufferSize

  for i in [0..b.length-1]
    divisor = Math.pow 256, (b.length - 1 - i)
    value = Math.floor (n / divisor)
    b[i] = (value % 256)
    n = n % divisor
  return b
root.numberToBuffer = numberToBuffer


# Parses a Buffer as a Big Endian Int and returns the correspodning JS Number
# Args:
#   buffer: the Buffer object
# Returns:
#   A JS Number
bufferToNumber = (buffer) ->
  assert.ok Buffer.isBuffer buffer
  accum = 0
  for i in [0..buffer.length-1]
    accum *= 256
    accum += buffer[i]
  return accum
root.bufferToNumber = bufferToNumber


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

