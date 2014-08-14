
import sys
import subprocess
import glob
import yaml
from SSHClient import SSHClient
from TCommand import TCommand




def __run_sysbench():
        cmd = "ruby jobs/benchmark_oltp_vmworld.rb config/mysql/mysql_percona.yaml config/benchmark/sysbench_10M_ROWS_100_TABLES.yaml config/scenario/24G_1800s.yaml"
        ssh = SSHClient("10.102.41.10","jenkins","123456")
        ssh.execute_command(cmd)



print "Starting TEST right here, right now"
__run_sysbench()
