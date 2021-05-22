#!/usr/bin/env python3
#
# dead simple tool to check if a port is visible to the world using ifconfig.co
#

import requests, sys

try:
    port = int(sys.argv[1])
except:
    sys.exit('usage: portcheck <portnumber>')

if port < 0 or port > 65535:
    sys.exit('error: argument must be a positive integer [0-65535]')

r = requests.get('https://ifconfig.co/port/' + str(port))

if r.json().get('reachable'):
    print('port', str(port), 'IS reachable')
else:
    print('port', str(port), 'is NOT reachable')
