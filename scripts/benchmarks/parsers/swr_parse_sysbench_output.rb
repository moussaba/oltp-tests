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
    state = "top of file"
    #read in data from console ouput
    string = IO.read(raw_file)
    string.each_line do |line|
      case state
      when "top of file"
        if line.include?("running benchmark trial 1") then
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
        state = "end of data"
      when "end of data"
        break
      end
    end
    # puts "read_queries #{@read_queries}"
    # puts "write_queries #{@write_queries}"
    # puts "other_queries #{@other_queries}"
    # puts "total_queries #{@total_queries}"
    # puts "transactions #{@transactions}"
    # puts "transactions_per_sec #{@transactions_per_sec}"
    # puts "deadlocks #{@deadlocks}"
    # puts "deadlocks_per_sec #{@deadlocks_per_sec}"
    # puts "rw_requests #{@rw_requests}"
    # puts "rw_requests_per_sec #{@rw_requests_per_sec}"
    # puts "other_ops #{@other_ops}"
    # puts "other_ops_per_sec #{@other_ops_per_sec}"
    # puts "total_time #{@total_time}"
    # puts "total_num_events #{@total_num_events}"
    # puts "total_time_exectution #{@total_time_exectution}"
    # puts "min_response_time #{@min_response_time}"
    # puts "avg_response_time #{@avg_response_time}"
    # puts "max_response_time #{@max_response_time}"
    # puts "nintynine_percentile_response_time #{@nintynine_percentile_response_time}"
    # puts "events #{@events}"
    # puts "execution_time #{@execution_time}"
    
    xml = Builder::XmlMarkup.new
    xml.instruct!
    
    xml.OLTP_test_statistics do
      xml.queries_performed do
        xml.read(@read_queries)
        xml.write(@write_queries)
        xml.other(@other_queries)
        xml.total(@total_queries)
      end
      xml.transactions do
        xml.transaction_count(@transactions)
        xml.transactions_per_second(@transactions_per_sec)
      end
      xml.deadlocks do
        xml.deadlock_count(@deadlocks)
        xml.deadlocks_per_second(@deadlocks_per_sec)
      end
      xml.rw_requests do
        xml.rw_request_count(@rw_requests)
        xml.rw_request_per_second(@rw_requests_per_sec)
      end
      xml.other_operations do
        xml.other_operations_count(@other_ops)
        xml.other_operations_per_second(@other_ops_per_sec)
      end
      xml.general_statistics do
        xml.total_time(@total_time)
        xml.total_events(@total_num_events)
        xml.total_time_event_execution(@total_time_exectution)
        xml.response_time do
          xml.min(@min_response_time)
          xml.avg(@avg_response_time)
          xml.max(@max_response_time)
          xml.ninty_nine_percentile(@nintynine_percentile_response_time)
        end
      end
      xml.treads_fairness do
        xml.events(@events)
        xml.execution_time(@execution_time)
      end
    end
    
    xml_data = xml.target!
    file = File.new("sysbench_statistics.xml","w")
    file.write(xml_data)
    file.close
  end
end

data = ParseSysbenchOutput.new(ARGV[0])
#data.write_to_xml()

