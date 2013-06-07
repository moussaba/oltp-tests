class ParseRwRatioTestOutput
  def initialize(csv_file_name, raw_file_name)
    @csv_file_name = csv_file_name
    @csv_file_data = ""
    @raw_file_name = raw_file_name
    @header = "io depth, system_usage, read iops, write iops, rw iops, read bw, write bw, rw bw, read latency, write latency, rw latency"
    @rand_read_bw = 0
    @rand_write_bw = 0
    @rand_read_iops = 0
    @rand_write_iops = 0
    @rand_read_latency = 0
    @rand_write_latency = 0
    @system_usage = 0
    @io_depth_index = 0
    
    @state = "start"

    #read in data from console ouput
    @raw_file_string = IO.read(@raw_file_name)
    
    @output_file = File.new(@csv_file_name, "w")
    @output_file.puts @header
    
  end

  def extract_data()
    @raw_file_string.each do |line|
      case @state

      when "start"
        if line.include?("------starting fio------------") then
          puts @state
          @state = "branch"
        end
        
      when "branch"
        if line.include?("read : io=")then
          @rand_read_iops = get_iops(line)
          @state = "get read data"
        end
        
        if line.include?("write: io=")then
          @rand_write_iops = get_iops(line)
          @state = "get write data"
        end
        
        if line.include?("Disk stats (")then
          write_to_csv_file()
        end
        
        if line.include?("Finished:") then
          @output_file.close()
        end
        
        if line.include?("cpu          :") then
          @system_usage = get_system_usage(line)
        end
        
      when "get read data"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          @rand_read_latency = get_avg_latency(line)
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          @rand_read_bw = get_bandwidth(line)
          @state = "branch"
        end
        
      when "get write data"
        if line.include?(" lat (usec): min") or line.include?(" lat (msec): min") then
          @rand_write_latency = get_avg_latency(line)
        end
        
        if line.include?("bw (KB/s)  :") or line.include?("bw (MB/s)  :") then
          @rand_write_bw = get_bandwidth(line)
          @state = "branch"
        end
        
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
  
  def get_system_usage(line)
    temp = line.split(",")
    temp = temp[1]
    temp = temp.split("=")
    temp = temp[1]
    temp = temp.split("%")
    system_usage = temp[0].to_f
    return system_usage
  end

  def write_to_csv_file()
    normalize_number = 1 #100/@system_usage
    output_line  = "#{@io_depth_index}"
    output_line += ",#{@system_usage}"
    output_line += ",#{@rand_read_iops.to_i * normalize_number}"
    output_line += ",#{@rand_write_iops.to_i * normalize_number}"
    output_line += ",#{@rand_read_iops.to_i + @rand_write_iops.to_i}"
    output_line += ",#{@rand_read_bw.to_f * normalize_number}"
    output_line += ",#{@rand_write_bw.to_f * normalize_number}"
    output_line += ",#{@rand_read_bw.to_f + @rand_write_bw.to_f}"
    output_line += ",#{@rand_read_latency}"
    output_line += ",#{@rand_write_latency}"
    output_line += ",#{@rand_read_latency.to_f + @rand_write_latency.to_f}"
    @output_file.puts output_line
    if @io_depth_index == 1 then
      @io_depth_index = 2
    else
      @io_depth_index += 2
    end
    @rand_read_bw = 0
    @rand_write_bw = 0
    @rand_read_iops = 0
    @rand_write_iops = 0
    @rand_read_latency = 0
    @rand_write_latency = 0
    @system_usage = 0
  end
  
end

data = ParseRwRatioTestOutput.new(ARGV[0], ARGV[1])
data.extract_data()
