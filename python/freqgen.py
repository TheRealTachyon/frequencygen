xtal = 32E6
tol = 1E4

def findMD(target):
    for M in range(1,256):
        for D in range(1, 256):
            result = xtal * float(M) / float(D)
            if abs(result - target) < tol:
                return (M,D)
            if result < target:
                break;

def getChecksum(packet):
    sum = 0
    for c in packet:
        sum += ord(c)
    
    return ("%02x" % (sum & 0xff))[-2:]

def makePacket(M,D):
    packet = "%02x%02x" % (M-1,D-1)
    return "$%s#%s" % (packet,getChecksum(packet))

while True:
    freq = input("Freq> ")
    f = float(freq)
    print "Calculating for frequency", f
    M,D = findMD(f)
    print "Using M =", M, "D =", D
    print "Actual frequency", xtal * (float(M) / float(D))
    print makePacket(M,D)
    

