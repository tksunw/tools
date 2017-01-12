#!/usr/bin/python

import re
import requests

ipsite   = u"https://4.ifcfg.me/ip"
henet    = u"https://dyn.dns.he.net/nic/update?hostname={hostname}&password={key}"
hostname = '< fqdn to update >'
key      = '< provided key >'

try:
    r = requests.get(ipsite)
except Exception as e:
    print "Error contacting IP lookup site", ipsite
else:
    ip = re.findall( r'[0-9]+(?:\.[0-9]+){3}', r.text )

    
    try:
        update = requests.post('https://dyn.dns.he.net/nic/update', data = { 'password': key, 'hostname': hostname, 'myip': ip }, verify="./root.crt")
    except Exception as e:
        print "Exception:", str(e)
    else:
        if update.reason == 'OK':
            print "Success: Dynamic DNS for", hostname, "updated to", ip
        else:
            print "Failure updating Dynamic DNS for", hostname

