#to use:
# ruby swr_parse_tpce_output <file.csv> <raw console output>
# parses tpce data for trial 1 and adds the transactions together
# creates new csv file if doesn't exist. 
# if a csv file does exist this appends another column of data to it.
# header is derived from raw console output filename
# 

class ParseTpceOutput
  def initialize(csv_file, raw_file)
    found_trial_1 = false
    data_fields = false
    line_count = 0
    @raw_data = Array.new
    @csv_data = Array.new
    @csv_file = csv_file
    @raw_file = raw_file

    #read in data from console ouput
    string = IO.read(@raw_file)
    string.each_line do |line|
      if line.include?("running benchmark trial 1") then
        found_trial_1 = true
      end
      if found_trial_1 == true and line.include?("sec. |    TR,    MF |   DM |   BV,    CP,    MW,    SD,    TL,    TO,    TS,    TU |") then
        data_fields = true
      end
      if (found_trial_1 == true) and (data_fields == true) then
        if line.include?("Stopping all threads...") then
          data_fields = false
          @raw_data.pop
        elsif line_count > 2
          if line.include?("|") then
            #puts line
            @raw_data.push line.chomp
          end
        end
        line_count += 1
      end
    end

    #if a csv file is specified, read that in as well
    if FileTest.exists?(@csv_file)then
      string = IO.read(csv_file)
      first_line = true
      string.each_line do |line|
        if first_line == true
          @old_header = line.chomp
          first_line = false
        else
          @csv_data.push line.chomp
        end
      end
    end
  end

  def add_up_transactions()
    @new_csv_data = Array.new
    @new_time_stamps = Array.new
    @raw_data.each do |line|
      #puts line
      parse_transaction_data(line) 
    end
  end
  
  def parse_transaction_data(line)
    tmp_data = line.split('|')
    #puts tmp_data
    @new_time_stamps.push tmp_data[0]
    transaction_string = tmp_data[1]
    tmp_data = transaction_string.split(',')
    trade_result = tmp_data[0].strip
    market_feed = tmp_data[1].strip
    data_maintenance = tmp_data[2].strip
    broker_volume = tmp_data[3].strip
    customer_position = tmp_data[4].strip
    market_watch = tmp_data[5].strip
    security_detail = tmp_data[6].strip
    trade_lookup = tmp_data[7].strip
    trade_order = tmp_data[8].strip
    trade_status = tmp_data[9].strip
    trade_update = tmp_data[10].strip

    transactions = trade_result.to_i + market_feed.to_i + data_maintenance.to_i + broker_volume.to_i
    transactions = transactions + customer_position.to_i + market_watch.to_i + security_detail.to_i
    transactions = transactions + trade_lookup.to_i + trade_order.to_i + trade_status.to_i + trade_update.to_i
    #puts transactions
    @new_csv_data.push transactions
  end

  
  def average_last_hour()
    start_average_at = @new_csv_data.size - 360
    counter = 0
    total = 0
    @new_csv_data.each do | num |
      if counter >= start_average_at then
        total += num.to_i
      end
      counter += 1
    end
    average = total/360
    @new_csv_data.push average
  end

  def write_to_csv()
    f = File.new(@csv_file, "w")
    counter = 0
    if @csv_data.size > 0 then
      f.puts"#{@old_header},#{@raw_file}"
      @csv_data.each do |line|
        f.puts "#{line},#{@new_csv_data[counter]}"
        counter += 1
      end
      
    else
      f.puts "time, #{@raw_file}"
      @new_time_stamps.each do |time|
        f.puts "#{time},#{@new_csv_data[counter]}"
        counter += 1
      end
      f.puts "999999,#{@new_csv_data[counter]}" #average of last hour
    end
    f.close
  end
end

data = ParseTpceOutput.new(ARGV[0], ARGV[1])
data.add_up_transactions()
data.average_last_hour()
data.write_to_csv()

