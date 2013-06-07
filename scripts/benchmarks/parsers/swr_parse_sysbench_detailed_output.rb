require "rubygems"

#to use:
# pass in name of console output file to get data from and the name of the csv file to write to
# ruby swr_parse_sysbench_detailed_output <console output file> <csv file>
# outputs a csv file with the following data
# transactions per second(tps),reads, writes, response time, register setting("address-setting")

#intended use is for jobs run with run_benchmark_with_register_config using only one configuration setting
class ParseSysbenchOutput
  def initialize(raw_file, csv_file, register_setting)
    @registerSetting = register_setting
    @f = File.new(csv_file, "w")
    #insert header
    @f.puts "seconds, threads, tps, reads, writes, response_time_ms, register_setting"

    state = "top of file"
    #read in data from console ouput file
    string = IO.read(raw_file)
    string.each_line do |line|
      case state
      when "top of file"
        # if line.include?(">>>---setting register") then
        #   tmp = line.split
        #   @registerSetting = tmp[2] + '-' + tmp[4]
        # end
        # 
        # this first appears after warmup run
        # so I use it to let me know the next data
        # are the real run
        if line.include?("Threads fairness:") then
          #puts "start of run"
          state = "start of run"
        end
      when "start of run"
        if line.include?("[3600s]") then
          #puts "starting data"
          state = "starting data"
        end
      when "starting data"
        #puts line
        #starts at record 3601 and goes to end of test data
        if line.include?("OLTP test statistics:") then
          #puts "end of data"
          state = "end of data"
        else
          if line.include?("[")
            writeToCsvFile(line)
          end
        end
      when "end of data"
        #puts "end of data"
        break
      end
    end
    @f.close
  end

  def writeToCsvFile(line)
    #puts line
    #puts [3601s] threads: 32, tps: 2501.01, reads/s: 34960.12, writes/s: 9993.03, response time: 32.68ms (99%)
    #into csv format including string from >>>---setting register 272 to ffff0002
    # header: time seconds, threads,  tps,      reads,    writes,   response time ms, register_setting
    # data:   3601,         32        2501.01,  34960.12, 9993.03,  32.68             272-ffff0002
    # this format is used to facilitate merging data sets in R
    tmp = line.split
    #puts tmp
    time = tmp[0]
    time = time[1..time.length-3]
    #puts time
    responseTime = tmp[11]
    responseTime = responseTime[0..responseTime.length-3]
    outputString = time + ',' + tmp[2] + tmp[4] + tmp[6] + tmp[8] + responseTime + ',' + @registerSetting
    @f.puts outputString
  end
end


    data = ParseSysbenchOutput.new(ARGV[0], ARGV[1], ARGV[2])

