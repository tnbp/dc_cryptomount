#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import serial
import getopt
import sys
import time
import termios
import hashlib
from getpass import getpass

DC_RELAYCTRL_VERSION = "0.1"

hexchars = "0123456789abcdef"

def main():
    try:
        opts, args = getopt.getopt(sys.argv[1:], "c:d:v")
    except getopt.GetoptError as err:
        print(err)
        printusage()
        sys.exit(1)
    port = "/dev/ttyUSB0"
    command = -1;
    for o, a in opts:
        if o == "-c":
            if a == "1" or a == "on" or a == "ON":
                command = 1;
            else:
                command = 0;
        elif o == "-d":
            port = a
        elif o == "-v":
            printversion()
            sys.exit(0)
        else:
            assert False, "unhandled option"
            printusage()
            sys.exit(1)
    
    if command == -1:
        printusage()
        sys.exit(1)
    
    try:
        t = open(port)
        attrs = termios.tcgetattr(t)
        attrs[2] = attrs[2] & ~termios.HUPCL
        termios.tcsetattr(t, termios.TCSAFLUSH, attrs)
        t.close()
    except FileNotFoundError as err:
        print("\033[1m[\033[91m-\033[39m]\033[0m ERROR: Could not open %s (%s)" % (port, err))
        sys.exit(1)
        
    
    s = serial.Serial()
    s.port = port
    try:
        s.open()
    except serial.SerialException as err:
        print("\033[1m[\033[95m*\033[39m]\033[0m " + err)
        sys.exit(1)

    outbuf = "DA7AC1BE" + str(command)
    s.write(outbuf.encode())
    challenge = s.readline().decode().rstrip()
    if challenge[:11] == "DCRELAYCTRL":     # for some reason, this is necessary. flushing buffers does not work
        s.write(outbuf.encode())
        challenge = s.readline().decode().rstrip()
    
    if challenge[:2] == "ON":
        print("\033[1m[\033[92m+\033[39m]\033[0m Already ON, exiting!")
        sys.exit(0)
    if challenge[:3] == "OFF":
        print("\033[1m[\033[92m+\033[39m]\033[0m Already OFF, exiting!")
        sys.exit(0)
    
    DC_RELAYCTRL_SECRET = getpass("\033[1m[\033[96m?\033[39m]\033[0m Enter shared secret: ")
    #print("Entered password: \"%s\" (length: %d)" % (DC_RELAYCTRL_SECRET, len(DC_RELAYCTRL_SECRET)))
    if len(DC_RELAYCTRL_SECRET) != 32:
        print("\033[1m[\033[91m-\033[39m]\033[0m ERROR: Shared secret must be a 256-bit ASCII string, exiting!")
        sys.exit(1)
    
    #print("Challenge: %s (length: %d)" % (challenge, len(challenge)))
    challenge_int = [0] * 32
    for i in range(32):
        challenge_int[i] = int(challenge[2 * i], 16) << 4
        challenge_int[i] |= int(challenge[2 * i + 1], 16)
    #print("Challenge as integers: ", end="")
    #for i in range(32):
    #    print("%d " % challenge_int[i], end="")
    #print("\nResponse (plain): ", end="")
    xord = [0] * 32
    xord_str = str()
    for i in range(len(challenge_int)):
        xord[i] = challenge_int[i] ^ ord(DC_RELAYCTRL_SECRET[i])
        xord_str += hexchars[xord[i] // 16]
        xord_str += hexchars[xord[i] % 16]
    #print("%s" % xord_str.encode())
    response_str = hashlib.sha512(xord_str.encode()).hexdigest()
    #print("Response (hashed): %s" % response_str)
    s.write(response_str.encode())
    time.sleep(1)
    outbuf = "DA7AC1BE" + str(command)
    s.flushOutput()
    s.flushInput()
    s.write(outbuf.encode())
    
    tries = 0
    
    while True:
        success = s.readline().decode().rstrip()
    
        if success[:2] == "ON":
            print("\033[1m[\033[92m+\033[39m]\033[0m Successfully turned ON!")
            exitcode = 0
            break
        elif success[:3] == "OFF":
            print("\033[1m[\033[92m+\033[39m]\033[0m Successfully turned OFF!")
            exitcode = 0
            break
        elif tries < 3:
            tries += 1
        else:
            print("\033[1m[\033[91m-\033[39m]\033[0m Status hasn't changed--wrong password?")
            exitcode = 1
            break

    s.close()
    sys.exit(exitcode)

def printversion():
    print("datacube RELAY CONTROL version %s" % DC_RELAYCTRL_VERSION);

def printusage(): 
    print("USAGE: %s -c (ON/OFF) [-d /dev/ttyUSB0]" % sys.argv[0]);
    print("\t-c\t\tspecify command (ON/OFF)");
    print("\t-d\t\tspecify device (default: /dev/ttyUSB0)");
    print("\t-v\t\tshow version info");

if __name__ == "__main__":
    main()
