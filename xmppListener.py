#!/usr/bin/python2

# xmppListener.py node@domain password 
#   listen for and print messagses from the same node@domain
#
# modified 2012-03-08
# from bot.py on http://xmpppy.sourceforge.net/
# $Id: bot.py,v 1.2 2006/10/06 12:30:42 normanr Exp $

import sys
import xmpp
#import pprint
#pp = pprint.PrettyPrinter(indent=4)

############################ Dump messages to terminal  #####################################

def messageCB(conn,mess):
    text=mess.getBody()
    user=mess.getFrom()
    # only output messages from ourself
    if sys.argv[1] == user.node + '@' + user.domain :
       sys.stdout.write(text)
       # flush needed to give output to pipe
       sys.stdout.flush()

############################# Connect #####################################

def StepOn(conn):
    try:
        conn.Process(1)
    except KeyboardInterrupt: return 0
    return 1

def GoOn(conn):
    while StepOn(conn): pass

if len(sys.argv)<3:
    print "Usage: bot.py username@server.net password"
else:
    jid=xmpp.JID(sys.argv[1])
    user,server,password=jid.getNode(),jid.getDomain(),sys.argv[2]

    conn=xmpp.Client(server,debug=[])
    conres=conn.connect()
    if not conres:
        print "Unable to connect to server %s!"%server
        sys.exit(1)

    authres=conn.auth(user,password)
    if not authres:
        print "Unable to authorize on %s - check login/password."%server
        sys.exit(1)
    conn.RegisterHandler('message',messageCB)
    conn.sendInitPresence()
    # don't care :)
    #if conres<>'tls':
    #    print "Warning: unable to estabilish secure connection - TLS failed!"
    #if authres<>'sasl':
    #    print "Warning: unable to perform SASL auth os %s. Old authentication method used!"%server
    #print "Bot started."
    GoOn(conn)
