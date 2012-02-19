###
# gnutella-packet.coffee - basic classes for Gnutella packets
###

assert = require('assert')

# Enable exports
root = exports ? this  # http://stackoverflow.com/questions/4214731/coffeescript-global-variables


# The types of packets we have!
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

  # Args:
  #   data: A Buffer
  constructor: (data) ->
    throw 'Do not instantiate the base class!'

  # Serializes this packet into a sendable buffer
  # Args:
  #   payload: a buffer containing a Gnutalla Payload
  # Returns:
  #   A Buffer of sendable data
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
    payloadLengthBuffer = numberToByteBuffer payload.length, 4
    payloadLengthBuffer.copy output, @HEADER_SIZE-4

    # set actual Payload
    payload.copy(output, @HEADER_SIZE)

    return output

    
  # See the Gnutella Spec:  http://www.stanford.edu/class/cs244b/gnutella_protocol_0.4.pdf
  id: null  # String Gnutella Packet ID
  type: null  # PacketType representing packet type
  ttl: null  # Integer TTL
  hops: null  # Integer Hops


# A Gnutella Ping Packet
class root.PingPacket extends root.GnutellaPacket
  # Args:
  #   data: A Buffer (optional)
  constructor: (data) ->
    if typeof data == Buffer
      # Construct a
      throw 'Createing a PingPacket from a Buffer is not implemented yet'

    data = data ? new Object()
    @id = data.id ? "7777777777777777"
    @type = PacketType.PING
    @ttl = data.ttl ? 7
    @hops = data.hops ? 0

  serialize: ->
    super new Buffer(0)

# A Gnutella Pong Packet
class root.PongPacket extends root.GnutellaPacket
  PAYLOAD_SIZE : 14

  # Args:
  #   data: A Buffer (optional)
  constructor: (data) ->
    if data instanceof Buffer
      # extract the pong information from the payload (i.e. the pong descriptor)
      @port = byteBufferToNumber(data.slice(@HEADER_SIZE, @HEADER_SIZE + 2))
      @address = byteBufferToAddress(data.slice(@HEADER_SIZE + 2, @HEADER_SIZE + 6))
      @numFiles = byteBufferToNumber(data.slice(@HEADER_SIZE + 6, @HEADER_SIZE + 10))
      @numKbShared = byteBufferToNumber(data.slice(@HEADER_SIZE + 10, @HEADER_SIZE + 14))

    else
      data = data ? new Object()
      @id = data.id ? "8888888888888888"
      @type = PacketType.PONG
      @ttl = data.ttl ? 7
      @hops = data.hops ? 0
      @port = data.port ? 0
      @address = data.address ? "137.137.137.137"
      @numFiles = data.numFiles ? 0
      @numKbShared = data.numKbShared ? 0

  serialize: ->
    payload = new Buffer(@PAYLOAD_SIZE)

    port = numberToByteBuffer(@port, 2)
    port.copy(payload, 0)

    address = addressToByteBuffer(@address, 4)
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

# Converts a JS number n into a Big Endian integer buffer
# Args:
#   n: the number to convert (floored to an Integer)
#   bufferSize: the number of bytes in the output buffer
# Returns:
#   A Buffer of size bufferSize that is the big endian integer representation
#   of n.
numberToByteBuffer = (n, bufferSize) ->
  n = Math.floor n
  b = new Buffer bufferSize

  for i in [0..b.length - 1]
    divisor = Math.pow 256, (b.length - 1 - i)
    value = Math.floor (n / divisor)
    b[i] = (value % 256)
    n = n % divisor
  return b

# Converts a Big Endian buffer into a JS number
byteBufferToNumber = (buffer) ->
  multiplier = 1
  result = 0

  for i in [(buffer.length - 1)..0]
    result = result + buffer[i] * multiplier
    multiplier = multiplier * 256

  return result

# Convert a Little Endian buffer into an IP Address
byteBufferToAddress = (buffer) ->
  result = buffer[0]

  for i in [1..buffer.length - 1]
    result = buffer[i] + "." + result

  return result

# Convert an IP Address into a Little Endian buffer
addressToByteBuffer = (address, bufferSize) ->
  n = Math.floor address.replace(".","")
  b = new Buffer bufferSize

  for i in [0..b.length - 1]
    b[i] = (n % 256)
    n = Math.floor (n / 256)

  return b
