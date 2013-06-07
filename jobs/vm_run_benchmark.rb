require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))
require 'rubygems'
#require 'rufus/scheduler'
require 'rbvmomi'
require 'openssl'

class JobRunBenchmark < SwrJob

  def initialize(configfile)

    super(ARGV)
    @job_name = ENV['JOB_NAME']
    @git_repo = "git@fmnxvgit01.micron.com:caching-testing/tests.git"
    @vcenter = RbVmomi::VIM.connect :host => @config["vsphere"]["host"], :user => @config["vsphere"]["username"], :password => @config["vsphere"]["password"]
    if @vcenter == nil
      puts "Failed to find vcenter"
      return
    end
    @dcenter = @vcenter.serviceInstance.find_datacenter(@config["vsphere"]["datacenter"])                                  
    if @dcenter == nil
      puts "Failed to find dcenter"
      return
    end
    @stdout_all=Hash.new
    @stderr_all=Hash.new
    @status_all=Hash.new
    @cmd_all=Hash.new
  end

  def pdi_set
        
        guest_ssh = SwrSsh.new("ookla01.micron.com","root","1234567")
        stdout,stderr,status,cmd = guest_ssh.execute("/opt/pxd/bin/pdi #{@pdi_state}",true,false,"ookla01 |")
  end


  def setup(verbose)

    #Shutdown before reconfigure
    @config["vms"].each do |vm,prop|
      myvm = @dcenter.find_vm(vm) or fail "VM  not found"
      if myvm.runtime.powerState == 'poweredOn'
          puts "#{vm} is powered ON, shutting down to reconfigure"
          myvm.ShutdownGuest
      end
    end

    @config["vms"].each do |vm,prop|
        myvm = @dcenter.find_vm(vm) or fail "VM  not found"
        #Timeout at some point....
        if myvm.runtime.powerState == 'poweredOn'
          puts "Waiting for #{vm} to shutdown"
          while myvm.runtime.powerState == 'poweredOn'
          end
        end
    end
      
    @config["vms"].each do |vm,prop|
      myvm = @dcenter.find_vm(vm) or fail "VM  not found"
      if myvm.runtime.powerState == 'poweredOff'
       memoryMB = prop["RAM"].to_i * 1024
       puts "Setting #{vm} RAM to #{memoryMB} MB"
       myvm.ReconfigVM_Task(:spec => RbVmomi::VIM.VirtualMachineConfigSpec(:memoryMB => memoryMB)).wait_for_completion
       puts "Powering up #{vm}..."
       myvm.PowerOnVM_Task.wait_for_completion
      end
    end
    puts "Waiting for VMs to start"
    sleep 240
  end

  def clone_git(verbose)

    @config["vms"].each do |vm,prop|
      myvm = @dcenter.find_vm(vm) or fail "VM  not found"

      if myvm.runtime.powerState == 'poweredOn'
        guest_ssh = SwrSsh.new(myvm.guest.ipAddress,"jenkins","123456")
        stdout,stderr,status,cmd = guest_ssh.execute("sudo umount ~/workspace/#{@job_name}/test_tmp/data",true,true,"#{vm} |")
        stdout,stderr,status,cmd = guest_ssh.execute("sudo rm -rf ~/workspace/#{@job_name}",true,false,"#{vm} |")
        @stdout_all[vm]=stdout
        @stderr_all[vm]=stderr
        @status_all[vm]=status
        @cmd_all[vm]=cmd
        stdout,stderr,status,cmd = guest_ssh.execute("git clone #{@git_repo} ~/workspace/#{@job_name}",true,false,"#{vm} |")
        #stdout,stderr,status,cmd = guest_ssh.execute("ls /usr/bin")
        @stdout_all[vm]+=stdout
        @stderr_all[vm]+=stderr
        @status_all[vm]+=status
        @cmd_all[vm]+=cmd

      end

    end

  end

  def run_benchmark(vm,cmd)
        myvm = @dcenter.find_vm(vm) or fail "VM  not found"
        guest_ssh = SwrSsh.new(myvm.guest.ipAddress,"jenkins","123456")
        stdout,stderr,status,cmd = guest_ssh.execute(cmd,true,false,"#{vm} |")
        @stdout_all[vm]+=stdout
        @stderr_all[vm]+=stderr
        @status_all[vm]+=status
        @cmd_all[vm]+=cmd
  end
  
  def get_jenkins_parameters
    @benchmark = ENV['SWR_CONFIGFILE_2_BENCHMARK']
    @mysql = ENV['SWR_CONFIGFILE_1_MYSQL']
    @scenario = ENV['SWR_CONFIGFILE_3_SCENARIO']
    @solution = ENV['SWR_CONFIGFILE_4_SOLUTION']
    @drive = ENV['SWR_CONFIGFILE_5_DRIVE']
    @pdi_state = ENV['SWR_PDI']
  end

  def print_output

      @stdout_all.each do |h,k|
           File.open("#{h}.log", "w+") do |f|
              f.write k
	   end
        #puts k
      end

      @stderr_all.each do |h,k|
           File.open("#{h}.log", "a+") do |f|
              f.write k
	   end
        #puts k
      end

      @cmd_all.each do |h,k|
           File.open("#{h}.log", "a+") do |f|
              f.write k
	   end
        #puts k
      end

      @status_all.each do |h,k|
           File.open("#{h}.log", "a+") do |f|
              f.write k
	   end
        #puts k
      end

  end

  def teardown(verbose)

    @config["vms"].each do |vm,prop|
      myvm = @dcenter.find_vm(vm) or fail "VM  not found"
      if myvm.runtime.powerState == 'poweredOn'
          puts "Shutting down #{vm}"
          myvm.ShutdownGuest
      end
    end

    @config["vms"].each do |vm,prop|
      myvm = @dcenter.find_vm(vm) or fail "VM  not found"
      if myvm.runtime.powerState == 'poweredOn'
        puts "Waiting for #{vm} to shutdown"
        #Timeout at some point....
        while myvm.runtime.powerState == 'poweredOn'
        end
      end
    end
   
  end

  def doit(verbose)

    if @mysql != nil
      mysql_config = "config/#{@mysql}"
    else
      puts "Mysql configuration missing...Quitting"
      exit 0
    end 

    if @benchmark != nil
      benchmark_config = "config/#{@benchmark}"
    else
      puts "Benchmark configuration missing...Quitting"
      exit 0
    end 

    if @scenario != nil
      scenario_config = "config/#{@scenario}"
    else
      puts "Scenario configuration missing...Quitting"
      exit 0
    end 

    if @drive != nil
      drive_config = "config/#{@drive}"
    else
      puts "Drive configuration missing...Quitting"
      exit 0
    end 

    if @solution != nil
      solution_config = "config/#{@solution}"
    else
      solution_config = ""
    end 

    #cmd = "cd ~/workspace/#{@job_name};sudo java -jar bin/jruby-test.jar jobs/run_benchmark.rb config/#{@mysql} config/#{@benchmark} config/#{@scenario} config/#{@drive}"
    cmd = "cd ~/workspace/#{@job_name};sudo java -jar bin/jruby-test.jar jobs/run_benchmark.rb #{mysql_config} #{benchmark_config} #{scenario_config} #{drive_config} #{solution_config}"
    
    vm_threads = Hash.new
    @config["vms"].each do |vm,prop|
      puts "Creating thread for #{vm}"
      vm_threads[vm] = Thread.new{run_benchmark(vm,cmd)}
    end 
    
    vm_threads.each do |h,t|
        t.join
    end

    # #Start Vscsi Collection
    # scheduler = Rufus::Scheduler.start_new


    # scheduler.in '5m' do
    #   startVscsci(verbose)
    # end

    # scheduler.in '8m' do
    #   collectVscsci(verbose)
    # end
    
  end

  # def startVscsi(verbose)
  #   guest_ssh = SwrSsh.new("ookla01.micron.com","root","1234567")
  #   stdout,stderr,status,cmd = guest_ssh.execute("vscsiStats -s -w 193578 -i 8224",true,false,"ookla01 |")
  #   stdout,stderr,status,cmd = guest_ssh.execute("vscsiStats -s -w 193578 -i 8225",true,false,"ookla01 |")
  #   @stdout_all[vm]+=stdout
  #   @stderr_all[vm]+=stderr
  #   @status_all[vm]+=status
  #   @cmd_all[vm]+=cmd
  # end

  # def collectVscsi
  #   guest_ssh = SwrSsh.new("ookla01.micron.com","root","1234567")
  #   stdout,stderr,status,cmd = guest_ssh.execute("vscsiStats -p -all",true,false,"ookla01 |")
  #   @stdout_all[vm]+=stdout
  #   @stderr_all[vm]+=stderr
  #   @status_all[vm]+=status
  #   @cmd_all[vm]+=cmd

  # end

end

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

j = SwrDriveInfo.new
j.print
verbose = true
job = JobRunBenchmark.new(ARGV)
job.get_jenkins_parameters
job.pdi_set
job.setup(verbose)
job.clone_git(verbose)
job.doit(verbose)
job.print_output
#job.teardown(verbose)

j.print
