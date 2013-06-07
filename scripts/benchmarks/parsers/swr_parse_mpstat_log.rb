
#this is setup to work with mpstat files generated
#with command: mpstat -u -P ALL -I SUM > xxx.log
#generates csv file for each cpu and all cpus
#output.all.csv, output.0.csv, output.1.csv etc
#usage ruby swr_parse_mpstat_log <logfile name> <output filename base>
class ParseMpStatLog
  def initialize(log_file_name, output_base_name)
    @output_base_name = output_base_name
    @log_file_name = log_file_name
    @header = "time, %usr, %nice, %sys, %iowait, %irq, %soft, %steal, %guest, %idle, intr/s"
    
    @cpu_all = ""
    @cpu_0 = ""
    @cpu_1 = ""
    @cpu_2 = ""
    @cpu_3 = ""
    @cpu_4 = ""
    @cpu_5 = ""
    @cpu_6 = ""
    @cpu_7 = ""
    @cpu_8 = ""
    @cpu_9 = ""
    @cpu_10 = ""
    @cpu_11 = ""
    @cpu_12 = ""
    @cpu_13 = ""
    @cpu_14 = ""
    @cpu_15 = ""
    
    @cpu_all_f = File.new("#{@output_base_name}_all.csv", "w")
    @cpu_all_f.puts @header
    @cpu_0_f = File.new("#{@output_base_name}_0.csv", "w")
    @cpu_0_f.puts @header
    @cpu_1_f = File.new("#{@output_base_name}_1.csv", "w")
    @cpu_1_f.puts @header
    @cpu_2_f = File.new("#{@output_base_name}_2.csv", "w")
    @cpu_2_f.puts @header
    @cpu_3_f = File.new("#{@output_base_name}_3.csv", "w")
    @cpu_3_f.puts @header
    @cpu_4_f = File.new("#{@output_base_name}_4.csv", "w")
    @cpu_4_f.puts @header
    @cpu_5_f = File.new("#{@output_base_name}_5.csv", "w")
    @cpu_5_f.puts @header
    @cpu_6_f = File.new("#{@output_base_name}_6.csv", "w")
    @cpu_6_f.puts @header
    @cpu_7_f = File.new("#{@output_base_name}_7.csv", "w")
    @cpu_7_f.puts @header
    @cpu_8_f = File.new("#{@output_base_name}_8.csv", "w")
    @cpu_8_f.puts @header
    @cpu_9_f = File.new("#{@output_base_name}_9.csv", "w")
    @cpu_9_f.puts @header
    @cpu_10_f = File.new("#{@output_base_name}_10.csv", "w")
    @cpu_10_f.puts @header
    @cpu_11_f = File.new("#{@output_base_name}_11.csv", "w")
    @cpu_11_f.puts @header
    @cpu_12_f = File.new("#{@output_base_name}_12.csv", "w")
    @cpu_12_f.puts @header
    @cpu_13_f = File.new("#{@output_base_name}_13.csv", "w")
    @cpu_13_f.puts @header
    @cpu_14_f = File.new("#{@output_base_name}_14.csv", "w")
    @cpu_14_f.puts @header
    @cpu_15_f = File.new("#{@output_base_name}_15.csv", "w")
    @cpu_15_f.puts @header

    @state = "start"
    @tmp = ["a", "b", "c"]

    #read in data from log file
    puts @log_file_name
    @log_file_string = IO.read(@log_file_name)
  end

  def extract_data()
    @log_file_string.each do |line|
      case @state

      when "start"
        if line.include?("%iowait") then
          @state = "get all cpu data"
          @tmp[2] = "ignore me for this pass"
        end

      when "get all cpu data"
        if line.include?("intr/s") then
          @state = "get all interrupt data"
        elsif line.size() < 3 then
          #do nothing
        else
          @tmp = line.split(" ")
          @record = "#{@tmp[0]} #{@tmp[1]}, #{@tmp[3]}, #{@tmp[4]}, #{@tmp[5]}, #{@tmp[6]}, #{@tmp[7]}, #{@tmp[8]}, #{@tmp[9]}, #{@tmp[10]}, #{@tmp[11]}"
        end
      
      when "get all interrupt data"
        if line.size() < 3 then
          @state = "write to files"
        else
          @tmp = line.split(" ")
          @record = ", #{@tmp[3]}"
        end
        
      when "write to files"
        @cpu_all_f.puts @cpu_all
        @cpu_0_f.puts @cpu_0
        @cpu_1_f.puts @cpu_1
        @cpu_2_f.puts @cpu_2
        @cpu_3_f.puts @cpu_3
        @cpu_4_f.puts @cpu_4
        @cpu_5_f.puts @cpu_5
        @cpu_6_f.puts @cpu_6
        @cpu_7_f.puts @cpu_7
        @cpu_8_f.puts @cpu_8
        @cpu_9_f.puts @cpu_9
        @cpu_10_f.puts @cpu_10
        @cpu_11_f.puts @cpu_11
        @cpu_12_f.puts @cpu_12
        @cpu_13_f.puts @cpu_13
        @cpu_14_f.puts @cpu_14
        @cpu_15_f.puts @cpu_15
        @cpu_all = ""
        @cpu_0 = ""
        @cpu_1 = ""
        @cpu_2 = ""
        @cpu_3 = ""
        @cpu_4 = ""
        @cpu_5 = ""
        @cpu_6 = ""
        @cpu_7 = ""
        @cpu_8 = ""
        @cpu_9 = ""
        @cpu_10 = ""
        @cpu_11 = ""
        @cpu_12 = ""
        @cpu_13 = ""
        @cpu_14 = ""
        @cpu_15 = ""
        @tmp[2] = "the show is over, move along"
        @state = "get all cpu data"
      end
        
      case @tmp[2]
      when "all"
        @cpu_all += @record
      when "1"
        @cpu_1 += @record
      when "2"
        @cpu_2 += @record
      when "3"
        @cpu_3 += @record
      when "4"
        @cpu_4 += @record
      when "5"
        @cpu_5 += @record
      when "6"
        @cpu_6 += @record
      when "7"
        @cpu_7 += @record
      when "8"
        @cpu_8 += @record
      when "9"
        @cpu_9 += @record
      when "10"
        @cpu_10 += @record
      when "11"
        @cpu_11 += @record
      when "12"
        @cpu_12 += @record
      when "13"
        @cpu_13 += @record
      when "14"
        @cpu_14 += @record
      when "15"
        @cpu_15 += @record
      else
        #do nothing
      end
    end
  end
end

data = ParseMpStatLog.new(ARGV[0], ARGV[1])
data.extract_data()
