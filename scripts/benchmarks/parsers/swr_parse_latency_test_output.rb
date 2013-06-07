

class ParseLatencyTestOutput
  def initialize(csv_file_name, raw_file_name)
    @csv_file_name = csv_file_name
    @csv_file_data = ""
    @raw_file_name = raw_file_name
    @header = "payload,IO Depth 1,IO Depth 2,IO Depth 4,IO Depth 8,IO Depth 16,IO Depth 32,IO Depth 64,IO Depth 128,IO Depth 256, IO Depth 512"
    
    @rand_read_1_job_latency = "random read 1 job latency usec"
    @rand_write_1_job_latency = "random write 1 job latency usec"
    @fifty_fifty_rand_read_1_job_latency = "50/50 random read 1 job latency usec"
    @fifty_fifty_rand_write_1_job_latency = "50/50 random write 1 job latency usec"
    @rand_read_16_jobs_latency = "random read 16 jobs latency usec"
    @rand_write_16_jobs_latency = "random write 16 jobs latency usec"
    @fifty_fifty_rand_read_16_jobs_latency = "50/50 random read 16 jobs latency usec"
    @fifty_fifty_rand_write_16_jobs_latency = "50/50 random write 16 jobs latency usec"
    @rand_read_1_job_bw = "random read 1 job bandwidth Mb/s"
    @rand_write_1_job_bw = "random write 1 job bandwidth Mb/s"
    @fifty_fifty_rand_read_1_job_bw = "50/50 random read 1 job bandwidth Mb/s"
    @fifty_fifty_rand_write_1_job_bw = "50/50 random write 1 job bandwidth Mb/s"
    @rand_read_16_jobs_bw = "random read 16 jobs bandwidth Mb/s"
    @rand_write_16_jobs_bw = "random write 16 jobs bandwidth Mb/s"
    @fifty_fifty_rand_read_16_jobs_bw = "50/50 random read 16 jobs bandwidth Mb/s"
    @fifty_fifty_rand_write_16_jobs_bw = "50/50 random write 16 jobs bandwidth Mb/s"
    
    @state = "start"

    #read in data from console ouput
    puts @raw_file_name
    @raw_file_string = IO.read(@raw_file_name)
    
    #if a csv file is specified, read that in as well
    if FileTest.exists?(@csv_file_name)then
      @csv_file_data = IO.read(@csv_file_name)
    end

  end

  def extract_data()
    @raw_file_string.each do |line|
      case @state

      when "start"
        if line.include?("------starting fio------------") then
          puts @state
          puts line
          @state = "look for run jobs"
        end

      when "look for run jobs"
        if line.include?("run_jobs") then
          puts @state
          puts line
          @state = "look for num jobs"
        end
        
        if line.include?("Finished:") then
          puts @state
          puts line
          @state = "write to csv file"
        end
        
      when "look for num jobs"
        if line.include?("numjobs=16") then
          puts @state
          puts line
          @state = "do random read 16 jobs"
        elsif line.include?("numjobs=1") then
          puts @state
          puts line
          @state = "do random read 1 job"
        end
        
      when "do random read 1 job"
        if line.include?("iodepth=") then
          puts line
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_1_job_latency += ", #{latency}"
        end

        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_1_job_bw += ", #{bandwidth}"
          @state = "do random write 1 job"
        end
        
      when "do random write 1 job"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_1_job_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_1_job_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "do fifty fifty random read 1 job"
        end
        
      when "do fifty fifty random read 1 job"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @fifty_fifty_rand_read_1_job_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @fifty_fifty_rand_read_1_job_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "do fifty fifty random write 1 job"
        end
        
      when "do fifty fifty random write 1 job"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @fifty_fifty_rand_write_1_job_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @fifty_fifty_rand_write_1_job_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "look for run jobs"
        end
        
      when "do random read 16 jobs"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_16_jobs_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_16_jobs_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "do random write 16 jobs"
        end
        
      when "do random write 16 jobs"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_16_jobs_latency += ", #{latency}"
        end
          
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_16_jobs_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "do fifty fifty random read 16 jobs"
        end
        
      when "do fifty fifty random read 16 jobs"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @fifty_fifty_rand_read_16_jobs_latency += ", #{latency}"
        end
          
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @fifty_fifty_rand_read_16_jobs_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "do fifty fifty random write 16 jobs"
        end
        
      when "do fifty fifty random write 16 jobs"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @fifty_fifty_rand_write_16_jobs_latency += ", #{latency}"
        end
          
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @fifty_fifty_rand_write_16_jobs_bw += ", #{bandwidth}"
          puts @state
          puts line
          @state = "look for run jobs"
        end
        
      when "write to csv file"
        puts @state
        puts @csv_file_name
        write_to_csv_file()
        
      end
    end
  end
  
  def get_avg_latency(line)
    temp = line.split(",")
    temp = temp[2]
    temp = temp.split("=")
    temp = temp[1]
    latency = temp.to_f
    if line.include?(" lat (usec):") then
      latency = temp.to_f
    else #line.include?(" lat (msec):") then
      latency = temp.to_f * 1000
    end
    return latency
  end

  def get_bandwidth(line)
    temp = line.split(",")
    temp = temp[3]
    temp = temp.split("=")
    if line.include?("bw (KB/s)  :") then
      bandwidth = temp[1]
      bandwidth = bandwidth.to_f/1000
    else #line.include?("bw (MB/s)  :") then
      bandwidth = temp[1]
    end
    return bandwidth
  end

  def write_to_csv_file()
    f = File.new(@csv_file_name, "w")
    if @csv_file_data != "" then
      f.puts @csv_file_data
      f.puts ""
    end
    f.puts @raw_file_name
    f.puts @header
    f.puts @rand_read_1_job_latency
    f.puts @rand_read_1_job_bw
    f.puts @rand_read_16_jobs_latency
    f.puts @rand_read_16_jobs_bw
    f.puts @fifty_fifty_rand_read_1_job_latency
    f.puts @fifty_fifty_rand_read_1_job_bw
    f.puts @fifty_fifty_rand_read_16_jobs_latency
    f.puts @fifty_fifty_rand_read_16_jobs_bw
    f.puts @rand_write_1_job_latency
    f.puts @rand_write_1_job_bw
    f.puts @rand_write_16_jobs_latency
    f.puts @rand_write_16_jobs_bw
    f.puts @fifty_fifty_rand_write_1_job_latency
    f.puts @fifty_fifty_rand_write_1_job_bw
    f.puts @fifty_fifty_rand_write_16_jobs_latency
    f.puts @fifty_fifty_rand_write_16_jobs_bw
    f.close()
  end
  
end

data = ParseLatencyTestOutput.new(ARGV[0], ARGV[1])
data.extract_data()
