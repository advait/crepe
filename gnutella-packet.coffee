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
  #   payload: (optional) A Gnutella payload buffer (without the header)
  #       luckily, PingPacket don't have payloads so this should be an
  #       empty buffer
  constructor: (data) ->
    if Buffer.isBuffer(data)
      assert.ok data.length == 0
    @type = PacketType.PING
    # Note: Ping Packets don't have any ping-specific attributes

  serialize: ->
    super new Buffer(0)


# A Gnutella Pong Packet
class root.PongPacket extends root.GnutellaPacket
  PAYLOAD_SIZE: 14

  # Args:
  #   data: A Buffer (optional)
  constructor: (data) ->
    if data instanceof Buffer
      # extract the pong information from the payload (i.e. the pong descriptor)
      assert.ok data.length == @PAYLOAD_SIZE
      @type = PacketType.PONG
      @port = bufferToNumber(data.slice(0, 2))
      @address = littleEndianToIp(data.slice(2, 6))
      @numFiles = bufferToNumber(data.slice(6, 10))
      @numKbShared = bufferToNumber(data.slice(10, 14))
    else  # Fill with default attrs
      # TODO(advait): remove default attrs
      @id = "8888888888888888"
      @type = PacketType.PONG
      @ttl ?= 7
      @hops ?= 0
      @port ?= 0
      @address ?= "137.137.137.137"
      @numFiles ?= 0
      @numKbShared ?= 0

  serialize: ->
    payload = new Buffer(@PAYLOAD_SIZE)

    port = numberToByteBuffer(@port, 2)
    port.copy(payload, 0)

    address = ipToLittleEndian(@address, 4)
    address.copy(payload, 2)

    numFiles = numberToByteBuffer(@numFiles, 4)
    numFiles.copy(payload, 6)

    numKbShared = numberToByteBuffer(@numKbShared, 4)
    numKbShared.copy(payload, 10)

    super new Buffer(payload)


# A Gnutella Connect Packet
class root.ConnectPacket extends root.GnutellaPacket
  # Args:
  #   data: A Buffer (optional)
  constructor: ->
    data = data ? new Object()
    @type = PacketType.CONNECT
    @ttl = data.ttl ? 1
    @hops = data.hops ? 0

  serialize: ->
    super new Buffer(0)


# A Gnutella Pong Packet
class root.PongPacket extends root.GnutellaPacket
  # Args:
  #   data: A BUffer (optional)
  constructor: (data) ->
    if Buffer.isBuffer(data)
      # Construct a PongPacket object from a raw Buffer
      throw 'Createing a PongPacket from a Buffer is not implemented yet'

    # Generic packet attributes
    # TODO(advait): remove defaults
    data = data ? new Object()
    @id = data.id ? "7777777777777777"
    @type = PacketType.PONG
    @ttl = data.ttl ? 0
    @hops = data.hops ? 0

    # Pong-specific packet attributes
    # TODO(advait): remove defaults
    @port = data.port ? 1337
    @ip = data.ip ? '255.255.255.255'
    @filesShared = data.filesShared ? 0
    @kbShared = data.kbShared ? 0

  serialize: ->
    output = new Buffer 14

    # set port
    portBuffer = numberToBuffer @port, 2
    portBuffer.copy output, 0

    # set ip
    ipBuffer = ipToLittleEndian @ip
    ipBuffer.copy output, 2

    # set filesShared
    filesSharedBuffer = numberToBuffer @filesShared, 4
    filesSharedBuffer.copy output, 6

    # set kbShared
    kbSharedBuffer = numberToBuffer @kbShared, 4
    kbSharedBuffer.copy output, 10

    super output


##############################################################################
# Utility methods
##############################################################################


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
  '#{buffer[0]}.#{buffer[1]}.#{buffer[2]}.#{buffer[3]}'

# Converts a Little Endian byte buffer to an ip address (string)
littleEndianToIp = (buffer) ->
  assert.ok buffer.length == 4
  '#{buffer[3]}.#{buffer[2]}.#{buffer[1]}.#{buffer[0]}'

