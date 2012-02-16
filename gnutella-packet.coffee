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


# A Gnutella Ping Packet
class root.PingPacket extends root.GnutellaPacket
  # Args:
  #   data: A Buffer (optional)
  constructor: (data) ->
    if Buffer.isBuffer(data)
      # Construct a PingPacket object from a raw Buffer
      throw 'Createing a PingPacket from a Buffer is not implemented yet'

    # Generic packet attributes
    # TODO(advait): remove defaults
    data = data ? new Object()
    @id = data.id ? "7777777777777777"
    @type = PacketType.PING
    @ttl = data.ttl ? 0
    @hops = data.hops ? 0

    # Note: Ping Packets don't have any ping-specific attributes

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


# Converts a JS number n into a Big Endian integer buffer
# Args:
#   n: the number to convert (floored to an Integer)
#   bufferSize: the number of bytes in the output buffer
# Returns:
#   A Buffer of size bufferSize that is the big endian integer representation
#   of n.
numberToBuffer = (n, bufferSize) ->
  n = Math.floor n
  b = new Buffer bufferSize

  for i in [0..b.length - 1]
    divisor = Math.pow 256, (b.length - 1 - i)
    value = Math.floor (n / divisor)
    b[i] = (value % 256)
    n = n % divisor
  return b


# Converts an ip address (string) into a Big Endian byte buffer
ipToBigEndian = (ip) ->
  ip = ip.split('.')
  assert.ok ip.length == 4
  output = new Buffer 4
  for i in [0..3]
    output[i] = parseInt ip[i]
  return output


# Converts an ip address (string) into a Little Endian byte buffer
ipToLittleEndian = (ip) ->
  ip = ip.split('.')
  assert.ok ip.length == 4
  output = new Buffer 4
  for i in [0..3]
    output[i] = parseInt ip[3-i]
  return output
