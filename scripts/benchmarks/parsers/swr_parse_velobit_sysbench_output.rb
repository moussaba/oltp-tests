#to use:
# ruby swr_parse_sysbench_output <file.csv> <raw console output>
# parses sysbench data for trial sets - trial 1, trial 2 - a column for each trial
# creates new csv file.
# rows are named by output paramters of sysbench, columns are named by trial numbers
# multiple sets of trials are appended to the bottom of the csv file separated by a blank line
#
# example of text to parse:
#blah, blah, blah text...
#------running benchmark trial 1------------
#sudo /home/jenkins/workspace/run_velobit_benchmarks/bin/sysbench/sysbench  --oltp-read-only=off --test=/home/jenkins/workspace/run_velobit_benchmarks/bin/sysbench/tests/db/oltp.lua --oltp-table-size=1000000 --max-time=10 --init-rng=on --num-threads=16 --max-requests=0 --oltp-dist-type=uniform --mysql-user=root run
#sysbench 0.5:  multi-threaded system evaluation benchmark
#
#Running the test with following options:
#Number of threads: 16
#Random number generator seed is 0 and will be ignored
#
#
#Threads started!
#
#OLTP test statistics:
#    queries performed:
#        read:                            635096
#        write:                           181456
#        other:                           90728
#        total:                           907280
#    transactions:                        45364  (4535.25 per sec.)
#    deadlocks:                           0      (0.00 per sec.)
#    read/write requests:                 816552 (81634.44 per sec.)
#    other operations:                    90728  (9070.49 per sec.)
#
#General statistics:
#    total time:                          10.0025s
#    total number of events:              45364
#    total time taken by event execution: 159.8649s
#    response time:
#         min:                                  1.43ms
#         avg:                                  3.52ms
#         max:                                 25.76ms
#         approx.  95 percentile:               9.83ms
#
#Threads fairness:
#    events (avg/stddev):           2835.2500/35.78
#    execution time (avg/stddev):   9.9916/0.00
#
#{
#blah blah blah - more tial runs follow, maybe more sets of trial runs follow
#

class ParseSysbenchOutput
  def initialize(csv_file_name, raw_file_name)
    @row_names = ["read","write","other","total","transactions","transactions_per_sec","deadlocks",
      "read-write requests","other ops", "total time",
      "total events", "total event exec time","response time min",
      "response time avg", "response time max", "95 percentile",
      "avg events", "avg exec time"]
    @array_index = 0
    @read_array = Array.new
    @write_array = Array.new
    @other_array = Array.new
    @total_array = Array.new
    @transactions_array = Array.new
    @transactions_per_sec_array = Array.new
    @deadlocks_array = Array.new
    @read_write_array = Array.new
    @other_ops_array = Array.new
    @total_time_array = Array.new
    @total_events_array = Array.new
    @total_event_exec_array = Array.new
    @response_min_array = Array.new
    @response_avg_array = Array.new
    @response_max_array = Array.new
    @nine_five_array = Array.new
    @avg_events_array = Array.new
    @avg_exec_array = Array.new
    @state = "start"
    @csv_file_name = csv_file_name
    @raw_file_name = raw_file_name
    @trial_set_counter = 0
    @velobit_ram_size = "0G"
    @csv_velobit_ram_size = "0G"
    @buffer_pool_size = "0G"
    @csv_buffer_pool_size = "0G"
    @velobit_cache_depth = "999"
    @csv_velobit_cache_depth = "999"

    #read in data from console ouput
    @raw_file_string = IO.read(@raw_file_name)
  end

  def extract_data()

    @raw_file_string.each do |line|
      case @state
      when "start"
        
        if line.include?("Write cache depth is set to") then
          data = line.strip
          data = data.split(" ")
          #-----clunky logic but works for now-----
          if @velobit_cache_depth != "0G" then
            @csv_velobit_cache_depth = @velobit_cache_depth
            puts "csv_velobit_cache_depth is #{@csv_velobit_cache_depth}"
          end
          @velobit_cache_depth = data[6]
          if @csv_velobit_cache_depth == "0G" then
            @csv_velobit_cache_depth = @velobit_cache_depth
            puts "csv_velobit_cache_depth is #{@csv_velobit_cache_depth}"
          end
          #-----end of clunky logic-----
          puts "Write cache depth is set to #{@velobit_cache_depth}"
        end

        if line.include?("RAM will be used by VeloBit Software") then
          data = line.strip
          data = data.split(" ")
          #-----clunky logic but works for now-----
          if @velobit_ram_size != "0G" then
            @csv_velobit_ram_size = @velobit_ram_size
            puts "csv_velobit_ram_size is #{@csv_velobit_ram_size}"
          end
          @velobit_ram_size = data[0]
          if @csv_velobit_ram_size == "0G" then
            @csv_velobit_ram_size = @velobit_ram_size
            puts "csv_velobit_ram_size is #{@csv_velobit_ram_size}"
          end
          #-----end of clunky logic-----
          puts "#{@velobit_ram_size} RAM will be used by VeloBit Software"
        end

        if line.include?("starting mysqld with buffer_pool_size") then
          data = line.chomp
          data = data.split("=")
          data = data[1]
          data = data.split("-")
          @csv_buffer_pool_size = @buffer_pool_size
          @buffer_pool_size = data[0]
          puts "starting mysqld with buffer_pool_size is #{@buffer_pool_size}"
        end

        if line.include?("running benchmark trial") then
          puts line
          trial_number = line[30].chr
          if trial_number == "1" then
            @state = "start new trial set"
            if @array_index > 0 then
              write_to_csv_file()
            end
          else
            @state = "continue trial set"
          end
        end
      when "start new trial set"
        puts "start new trial set"
        @csv_velobit_ram_size = @velobit_ram_size
        @csv_velobit_cache_depth = @velobit_cache_depth
        @trial_set_counter += 1
        @array_index = 0
        @read_array = []
        @write_array = []
        @other_array = []
        @total_array = []
        @transactions_array = []
        @transactions_per_sec_array = []
        @deadlocks_array = []
        @read_write_array = []
        @other_ops_array = []
        @total_time_array = []
        @total_events_array = []
        @total_event_exec_array = []
        @response_min_array = []
        @response_avg_array = []
        @response_max_array = []
        @nine_five_array = []
        @avg_events_array = []
        @avg_exec_array = []
        @state = "look for read"

      when "continue trial set"
        puts "continue trial set"
        @array_index = @array_index + 1
        @state = "look for read"

      when "look for read"
        if line.include?("read:") then
          data = line.split(":")
          @read_array[@array_index] = data[1].strip
          @state = "look for write"
          puts "read: is #{@read_array[@array_index]}"
        end

      when "look for write"
        if line.include?("write:") then
          data = line.split(":")
          @write_array[@array_index] = data[1].strip
          @state = "look for other"
          puts "write: is #{@write_array[@array_index]}"
        end

      when "look for other"
        if line.include?("other:") then
          data = line.split(":")
          @other_array[@array_index] = data[1].strip
          @state = "look for total"
          puts "other: is #{@other_array[@array_index]}"
        end

      when "look for total"
        if line.include?("total:") then
          data = line.split(":")
          @total_array[@array_index] = data[1].strip
          @state = "look for transactions"
          puts "total: is #{@total_array[@array_index]}"
        end

      when "look for transactions"
        if line.include?("transactions:") then
          data = line.split(":")
          data = data[1].strip
          data = data.split(" ")
          @transactions_array[@array_index] = data[0]
          tmp = data[1].split("(")
          @transactions_per_sec_array[@array_index] = tmp[1]
          @state = "look for deadlocks"
          puts "transactions: is #{@transactions_array[@array_index]}"
        end

      when "look for deadlocks"
        if line.include?("deadlocks:") then
          data = line.split(":")
          data = data[1].strip
          data = data.split(" ")
          @deadlocks_array[@array_index] = data[0]
          @state = "look for read-write requests"
          puts "deadlocks: is #{@deadlocks_array[@array_index]}"
        end

      when "look for read-write requests"
        if line.include?("read/write requests:") then
          data = line.split(":")
          data = data[1].strip
          data = data.split(" ")
          @read_write_array[@array_index] = data[0]
          @state = "look for other operations"
          puts "read/write requests: is #{@read_write_array[@array_index]}"
        end

      when "look for other operations"
        if line.include?("other operations:") then
          data = line.split(":")
          data = data[1].strip
          data = data.split(" ")
          @other_ops_array[@array_index] = data[0]
          @state = "look for total time"
          puts "other operations: is #{@other_ops_array[@array_index]}"
        end

      when "look for total time"
        if line.include?("total time:") then
          data = line.split(":")
          data = data[1].strip
          @total_time_array[@array_index] = data.chomp("s")
          @state = "look for total number of events"
          puts "total time: is #{@total_time_array[@array_index]}"
        end

      when "look for total number of events"
        if line.include?("total number of events:") then
          data = line.split(":")
          @total_events_array[@array_index] = data[1].strip
          @state = "look for total time taken by event execution"
          puts "total number of events: is #{@total_events_array[@array_index]}"
        end

      when "look for total time taken by event execution"
        if line.include?("total time taken by event execution:") then
          data = line.split(":")
          data = data[1].strip
          @total_event_exec_array[@array_index] = data.chomp("s")
          @state = "look for min"
          puts "total time taken by event execution: is #{@total_event_exec_array[@array_index]}"
        end

      when "look for min"
        if line.include?("min:") then
          data = line.split(":")
          data = data[1].strip
          @response_min_array[@array_index] = data.chomp("ms")
          @state = "look for avg"
          puts "min: is #{@response_min_array[@array_index]}"
        end

      when "look for avg"
        if line.include?("avg:") then
          data = line.split(":")
          data = data[1].strip
          @response_avg_array[@array_index] = data.chomp("ms")
          @state = "look for max"
          puts "avg: is #{@response_avg_array[@array_index]}"
        end

      when "look for max"
        if line.include?("max:") then
          data = line.split(":")
          data = data[1].strip
          @response_max_array[@array_index] = data.chomp("ms")
          @state = "look for 95 percentile"
          puts "max: is #{@response_max_array[@array_index]}"
        end

      when "look for 95 percentile"
        if line.include?("95 percentile:") then
          data = line.split(":")
          data = data[1].strip
          @nine_five_array[@array_index] = data.chomp("ms")
          @state = "look for events"
          puts "95 percentile: is #{@nine_five_array[@array_index]}"
        end

      when "look for events"
        if line.include?("events (avg/stddev):") then
          data = line.split(":")
          data = data[1].strip
          data = data.split("/")
          @avg_events_array[@array_index] = data[0]
          @state = "look for execution time"
          puts "events (avg/stddev): is #{@avg_events_array[@array_index]}"
        end

      when "look for execution time"
        if line.include?("execution time (avg/stddev):") then
          data = line.split(":")
          data = data[1].strip
          data = data.split("/")
          @avg_exec_array[@array_index] = data[0]
          @state = "start"
          puts "execution time (avg/stddev): is #{@avg_exec_array[@array_index]}"
        end
      end
    end
    @csv_buffer_pool_size = @buffer_pool_size
    write_to_csv_file()
  end

  def write_to_csv_file()
    f = File.new(@csv_file_name, "a")
    trial_num = @array_index + 1
    row_index = 0
    f.puts ""
    if @csv_velobit_ram_size != "0G"
      f.puts "trial set #{@trial_set_counter} velobit size #{@csv_velobit_ram_size} mysqld buffer size #{@csv_buffer_pool_size}"
      puts "writing to csv file #{@trial_set_counter} #{@csv_velobit_ram_size} #{@csv_buffer_pool_size}"
    elsif @csv_velobit_cache_depth != "999"
      f.puts "trial set #{@trial_set_counter} velobit cache depth #{@csv_velobit_cache_depth} mysqld buffer size #{@csv_buffer_pool_size}"
      puts "writing to csv file #{@trial_set_counter} #{@csv_velobit_cache_depth} #{@csv_buffer_pool_size}"
    else
      f.puts "trial set #{@trial_set_counter} mysqld buffer size #{@csv_buffer_pool_size}"
      puts "writing to csv file #{@trial_set_counter} #{@csv_buffer_pool_size}"
    end

    row_avg = 0
    trial_num.times { |i| row_avg += @read_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@read_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @write_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@write_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @other_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@other_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @total_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@total_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @transactions_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@transactions_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @transactions_per_sec_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@transactions_per_sec_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1
    
    row_avg = 0
    trial_num.times { |i| row_avg += @deadlocks_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@deadlocks_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @read_write_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@read_write_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @other_ops_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@other_ops_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @total_time_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@total_time_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @total_events_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@total_events_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @total_event_exec_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@total_event_exec_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @response_min_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@response_min_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @response_avg_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@response_avg_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @response_max_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@response_max_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @nine_five_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@nine_five_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @avg_events_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@avg_events_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    row_avg = 0
    trial_num.times { |i| row_avg += @avg_exec_array[i-1].to_f}
    row_avg = row_avg/trial_num
    row_string = @row_names[row_index]
    trial_num.times { |i| row_string += ",#{@avg_exec_array[i-1]}"}
    row_string += ",#{row_avg}"
    f.puts row_string
    row_index += 1

    f.close()
  end
end

data = ParseSysbenchOutput.new(ARGV[0], ARGV[1])
data.extract_data()
