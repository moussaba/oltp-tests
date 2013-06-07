

class ParseRwRatioTestOutput
  def initialize(csv_file_name, raw_file_name)
    @csv_file_name = csv_file_name
    @csv_file_data = ""
    @raw_file_name = raw_file_name
    @header = "measurement,r0-w100,r10-w90,r30-w70,r50-w50,r70-w30,r90-w10,r100-w0"
    
    @rand_read_bw = "random read_bw Mb/s"
    @rand_write_bw = "random write_bw Mb/s"
    @rand_read_iops = "random read_iops"
    @rand_write_iops = "random write_iops"
    @rand_read_latency = "random read_latency usec"
    @rand_write_latency = "random write_latency usec"
    
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
          @state = "do randrw_0_100"
        end

      when "do randrw_0_100"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_read_iops += ", 0"
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", 0"
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", 0"
          @rand_write_bw += ", #{bandwidth}"
          @state = "do randrw 10 90 read"
        end
        
      when "do randrw 10 90 read"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", #{bandwidth}"
          @state = "do randrw 10 90 write"
        end
        
      when "do randrw 10 90 write"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", #{bandwidth}"
          @state = "do randrw 30 70 read"
        end
        
      when "do randrw 30 70 read"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", #{bandwidth}"
          @state = "do randrw 30 70 write"
        end
        
      when "do randrw 30 70 write"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", #{bandwidth}"
          @state = "do randrw 50 50 read"
        end
                    
      when "do randrw 50 50 read"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", #{bandwidth}"
          @state = "do randrw 50 50 write"
        end

      when "do randrw 50 50 write"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", #{bandwidth}"
          @state = "do randrw 70 30 read"
        end
          
      when "do randrw 70 30 read"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", #{bandwidth}"
          @state = "do randrw 70 30 write"
        end
        
      when "do randrw 70 30 write"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", #{bandwidth}"
          @state = "do randrw 90 10 read"
        end
              
      when "do randrw 90 10 read"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_read_bw += ", #{bandwidth}"
          @state = "do randrw 90 10 write"
        end
        
      when "do randrw 90 10 write"
        if line.include?("write: io=")then
          iops = get_iops(line)
          @rand_write_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", #{bandwidth}"
          @state = "randrw 100 0"
        end

      when "randrw 100 0"
        if line.include?("read : io=")then
          iops = get_iops(line)
          @rand_write_iops += ", 0"
          @rand_read_iops += ", #{iops}"
        end
        
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          latency = get_avg_latency(line)
          @rand_write_latency += ", 0"
          @rand_read_latency += ", #{latency}"
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          bandwidth = get_bandwidth(line)
          @rand_write_bw += ", 0"
          @rand_read_bw += ", #{bandwidth}"
          @state = "look for Finished"
        end
        
      when "look for Finished"
        if line.include?("Finished:") then
          puts line
          @state = "write to csv file"
        end
          
      when "write to csv file"
        puts @csv_file_name
        write_to_csv_file()
        
      end
    end
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

  def get_iops(line)
    temp = line.split(",")
    temp = temp[2]
    temp = temp.split("=")
    iops = temp[1]
    return iops
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

  def write_to_csv_file()
    f = File.new(@csv_file_name, "w")
    if @csv_file_data != "" then
      f.puts @csv_file_data
      f.puts ""
    end
    f.puts @raw_file_name
    f.puts @header
    f.puts @rand_read_bw
    f.puts @rand_read_iops
    f.puts @rand_read_latency
    f.puts @rand_write_bw    
    f.puts @rand_write_iops
    f.puts @rand_write_latency
    
    f.close()
  end
  
end

data = ParseRwRatioTestOutput.new(ARGV[0], ARGV[1])
data.extract_data()
