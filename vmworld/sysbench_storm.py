
import sys
import subprocess
import glob
import yaml
from SSHClient import SSHClient
from TCommand import TCommand




def __run_fio(self):
        threads = []
        tid = 1
        cmd = "cd ~/santa/;sudo python initiator.py -F;sudo bash ./run_ioscripts.sh | tee run.out"
        for initiator in self.config['initiators']:
            t = TCommand(tid,initiator,cmd)
            tid += 1
            t.start()
            threads.append(t)
        for t in threads:
            t.join()
        print "Run Complete"