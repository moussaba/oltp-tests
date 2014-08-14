import threading
from SSHClient import SSHClient

class TCommand(threading.Thread):

    def __init__(self,threadID,hostname,command):
        threading.Thread.__init__(self)
        self.hostname = hostname
        self.command = command

    def run(self):
        print "Executing %s on %s" % (self.command,self.hostname)
        ssh = SSHClient(self.hostname,"jenkins")
        ssh.execute(self.command)
