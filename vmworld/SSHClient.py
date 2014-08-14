import subprocess
import sys
import os
import paramiko


class SSHClient:

    def __init__(self,hostname,user,passwd):
        self.hostname = hostname
        self.username = username
        self.ssh = paramiko.SSHClient()
        self.ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        try:
            self.ssh.connect(hostname,username=user,password=passwd)
            self.transport = self.ssh.get_transport()
        except socket.error as e:
            print "Failed to Connect to %s" % hostname
            os.exit(0)

    def execute(self,command,timeout=10):
        hostname = self.username + "@" + self.hostname
        print "Executing command: %s on %s" % (command,hostname)
        stdin,stdout,stderr = self.ssh.exec_command(command)
        #ssh = subprocess.Popen(["ssh","%s" % hostname, command],shell=False,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        self.__read_output(stdin,stdout,stderr)

        if self.transport is None:
                print "Connection to %s lost"  % hostname
                return -1

        session = self.transport_open_session()
        session.set_combine_stderr(True)
        session.get_pty()
        session.exec_command(command)
        output = self._poll(session,timeout)
        status = session.recv_exit_status()
        return status,output



    def _poll(self,timeout):

        interval = 0.1
        maxseconds = timeout
        maxcount = maxseconds / interval

        # Poll until completion or timeout
        # Note that we cannot directly use the stdout file descriptor
        # because it stalls at 64K bytes (65536).
        input_idx = 0
        timeout_flag = False
        start = datetime.datetime.now()
        start_secs = time.mktime(start.timetuple())
        output = ''
        session.setblocking(0)
        while True:
            if session.recv_ready():
                data = session.recv(self.bufsize)
                output += data
                self.info('read %d bytes, total %d' % (len(data), len(output)))
 
                if session.send_ready():
                    # We received a potential prompt.
                    # In the future this could be made to work more like
                    # pexpect with pattern matching.
                    if input_idx < len(input_data):
                        data = input_data[input_idx] + '\n'
                        input_idx += 1
                        self.info('sending input data %d' % (len(data)))
                        session.send(data)
 
            self.info('session.exit_status_ready() = %s' % (str(session.exit_status_ready())))
            if session.exit_status_ready():
                break
 
            # Timeout check
            now = datetime.datetime.now()
            now_secs = time.mktime(now.timetuple()) 
            et_secs = now_secs - start_secs
            self.info('timeout check %d %d' % (et_secs, maxseconds))
            if et_secs > maxseconds:
                self.info('polling finished - timeout')
                timeout_flag = True
                break
            time.sleep(0.200)
 
        self.info('polling loop ended')
        if session.recv_ready():
            data = session.recv(self.bufsize)
            output += data
            self.info('read %d bytes, total %d' % (len(data), len(output)))
 
        self.info('polling finished - %d output bytes' % (len(output)))
        if timeout_flag:
            self.info('appending timeout message')
            output += '\nERROR: timeout after %d seconds\n' % (timeout)
            session.close()
 
        return output
    def copy(self,src,dst):
        destination = self.username + "@" + self.hostname+":"+dst

        print "Copying %s to %s" % (src,destination)
        scp = subprocess.Popen(["scp",src, destination],shell=False,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        self.__read_output(scp)


    def __read_output(self,stdin,stdout,stderr):
        result = stdout.readlines()

        if result == []:
            try:
                error = stderr.readlines()
                print >> sys.stderr, "Error: %s" % error
            except:
               print 
        else:
            for r in result:
                print(r.rstrip("\n"))

    def connected(self):
        return self.transport is not None


    def main():
        ssh = SSHClient("superbox","jenkins","123456")

        ssh.execute("cat /proc/meminfo")

if __name__ == '__main__':
    main()

