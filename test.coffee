###
# test.coffee - Random sanity tests for crepe
###
#
gp = require('./gnutella-packet.js')

# Test the createion of a new Ping Packet
p = new gp.PingPacket()
console.log p
console.log p.serialize()

console.log "\n--------------------------------------------\n"

# Test the createion of a new Pong Packet
p = new gp.PongPacket()
console.log p
console.log p.serialize()
