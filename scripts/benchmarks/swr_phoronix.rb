require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))
#Need to install sudo yum install php php-cli php-xml php-gd php-process
class SwrPhoronix < SwrBenchmarkTemplate
    def load(verbose)
        job_name = ENV['JOB_NAME']
        cmd = "export PTS_DIR=~/workspace/#{job_name}/bin/phoronix/share/phoronix-test-suite"
        cmd += ";#{@args["binary"]} install pts/disk"
        #cmd += ";#{@args["binary"]} install aio-stress"
        @shell.execute(cmd,verbose=true,status_can_be_nonzero=false)
    end
    def start(verbose)
        if @args["binary"] == nil then return Array.new end
        job_name = ENV['JOB_NAME']
        cmd = "export PTS_DIR=~/workspace/#{job_name}/bin/phoronix/share/phoronix-test-suite"
        cmd += ";#{@args["binary"]} "
        cmd += process_named_args(@args["named_args"])
        cmd += process_short_args(@args["short_args"])
        cmd += process_unnamed_args(@args["unnamed_args"])
        cmd += " #{@args["extra_args"]} "
        return @shell.execute(cmd,verbose)
    end

end
