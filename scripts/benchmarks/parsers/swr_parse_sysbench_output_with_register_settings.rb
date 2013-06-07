require "rubygems"
require "builder"

#to use:
# pass in name of console output file to get stats from
# ruby swr_parse_sysbench_stats <console output>
# outputs an xml file <sysbench_stats.xml> with the following stats
# OLTP test statistics:
#     queries performed:
#         read:                            195951546
#         write:                           0
#         other:                           27993078
#         total:                           223944624
#     transactions:                        13996539 (7775.84 per sec.)
#     deadlocks:                           0      (0.00 per sec.)
#     read/write requests:                 195951546 (108861.71 per sec.)
#     other operations:                    27993078 (15551.67 per sec.)
# 
# General statistics:
#     total time:                          1800.0043s
#     total number of events:              13996539
#     total time taken by event execution: 57577.7134s
#     response time:
#          min:                                  1.58ms
#          avg:                                  4.11ms
#          max:                               4151.83ms
#          approx.  99 percentile:              12.24ms
# 
# Threads fairness:
#     events (avg/stddev):           437391.8438/1937.63
#     execution time (avg/stddev):   1799.3035/0.01

class ParseSysbenchOutput
  def initialize(raw_file)
    state = "top of run"
    out_file = File.new("Parsed_output.csv", "w")
    header = "address,setting,read_queries,write_queries,other_queries,other_queries,transactions,transactions_per_sec,deadlocks,"
    header += "deadlocks_per_sec,rw_requests,rw_requests_per_sec,other_ops,other_ops_per_sec,total_time,total_num_events,"
    header += "total_time_exectution,min_response_time,avg_response_time,max_response_time,nintynine_percentile_response_time,"
    header += "events,execution_time"
    out_file.puts header
    #read in data from console ouput
    string = IO.read(raw_file)
    string.each_line do |line|
      @out_string = ""
      case state
      when "top of run"
        if line.include?(">>>---running benchmark trial") then
          state = "get register setting"
        end
      when "get register setting"
        if line.include?(">>>---setting register") then
          tmp = line.split(" ")
          @register_address = "#{tmp[2]}"
          @register_value = "#{tmp[4]}"
          state = "skip warmup OLTP statistics"
        end
      when "skip warmup OLTP statistics"
        if line.include?("OLTP test statistics:") then
          state = "start of run"
        end
      when "start of run"
        if line.include?("OLTP test statistics:") then
          state = "top of OLTP stats"
        end
      when "top of OLTP stats"
        if line.include?("queries performed:") then
          state = "reads"
        end
      when "reads"
        tmp = line.split(":")
        @read_queries = tmp[1].strip
        state = "writes"
      when "writes"
        tmp = line.split(":")
        @write_queries = tmp[1].strip
        state = "other transactions"
      when "other transactions"
        tmp = line.split(":")
        @other_queries = tmp[1].strip
        state = "total"
      when "total"
        tmp = line.split(":")
        @total_queries = tmp[1].strip
        state = "transactions"
      when "transactions"
        tmp = line.split(" ")
        @transactions = tmp[1].strip
        @transactions_per_sec = tmp[2].strip
        @transactions_per_sec = @transactions_per_sec[1..@transactions_per_sec.length]
        state = "deadlocks"
      when "deadlocks"
        tmp = line.split(" ")
        @deadlocks = tmp[1].strip
        @deadlocks_per_sec = tmp[2]
        @deadlocks_per_sec = @deadlocks_per_sec[1..@deadlocks_per_sec.length]
        state = "read write requests"
      when "read write requests"
        tmp = line.split(" ")
        @rw_requests = tmp[2].strip
        @rw_requests_per_sec = tmp[3].strip
        @rw_requests_per_sec = @rw_requests_per_sec[1..@rw_requests_per_sec.length]
        state = "other operations"
      when "other operations"
        tmp = line.split(" ")
        @other_ops = tmp[2].strip
        @other_ops_per_sec = tmp[3].strip
        @other_ops_per_sec = @other_ops_per_sec[1..@other_ops_per_sec.length]
        state = "total time"
      when "total time"
        if line.include?("total time:") then
          tmp = line.split(" ")
          @total_time = tmp[2].strip
          state = "total number of events"
        end
      when "total number of events"
        tmp = line.split(" ")
        @total_num_events = tmp[4].strip
        state = "total time execution"
      when "total time execution"
        tmp = line.split(" ")
        @total_time_exectution = tmp[6].strip
        state = "response time"
      when "response time"
        if line.include?("min:") then
          tmp = line.split(" ")
          @min_response_time = tmp[1].strip
          state = "avg response time"
        end
      when "avg response time"
        tmp = line.split(" ")
        @avg_response_time = tmp[1].strip
        state = "max response time"
      when "max response time"
        tmp = line.split(" ")
        @max_response_time = tmp[1].strip
        state = "99 percentile response time"
      when "99 percentile response time"
        tmp = line.split(" ")
        @nintynine_percentile_response_time = tmp[3].strip
        state = "Threads fairness"
      when "Threads fairness"
        if line.include?("events (avg/stddev):") then
          tmp = line.split(" ")
          @events = tmp[2].strip
          state = "execution time"
        end
      when "execution time"
        tmp = line.split(" ")
        @execution_time = tmp[3].strip
        
        @out_string = "#{@register_address},"
        @out_string += "#{@register_value},"
        @out_string += "#{@read_queries},"
        @out_string += "#{@write_queries},"
        @out_string += "#{@other_queries},"
        @out_string += "#{@total_queries},"
        @out_string += "#{@transactions},"
        @out_string += "#{@transactions_per_sec},"
        @out_string += "#{@deadlocks},"
        @out_string += "#{@deadlocks_per_sec},"
        @out_string += "#{@rw_requests},"
        @out_string += "#{@rw_requests_per_sec},"
        @out_string += "#{@other_ops},"
        @out_string += "#{@other_ops_per_sec},"
        @out_string += "#{@total_time},"
        @out_string += "#{@total_num_events},"
        @out_string += "#{@total_time_exectution},"
        @out_string += "#{@min_response_time},"
        @out_string += "#{@avg_response_time},"
        @out_string += "#{@max_response_time},"
        @out_string += "#{@nintynine_percentile_response_time},"
        @out_string += "#{@events},"
        @out_string += "#{@execution_time}"
        out_file.puts @out_string
        state = "top of run"
      end
    end
    out_file.close
  end
end

data = ParseSysbenchOutput.new(ARGV[0])