#to use:
# ruby swr_parse_tpcc_output <file.csv> <raw console output>
# parses tpcc data for trial 1 and adds the transactions together
# creates new csv file if doesn't exist. 
# if a csv file does exist this appends another column of data to it.
# header is derived from raw console output filename
# 

class ParseTpccOutput
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
      if found_trial_1 == true and line.include?("MEASURING START.") then
        data_fields = true
      end
      if (found_trial_1 == true) and (data_fields == true) then
        if line.include?("STOPPING THREADS") then
          data_fields = false
          @raw_data.pop
        else if line_count > 2
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

    def add_up_transactions()
      @new_csv_data = Array.new
      @new_time_stamps = Array.new
      @raw_data.each do |line|
        tmp_data = line.split(',')
        @new_time_stamps.push tmp_data[0]

        test = tmp_data[1].to_s
        indexnum = test.index("(")
        orders = tmp_data[1][0,indexnum]

        test = tmp_data[2].to_s
        indexnum = test.index("(")
        payments = tmp_data[2][0,indexnum]

        test = tmp_data[3].to_s
        indexnum = test.index("(")
        order_status = tmp_data[3][0,indexnum]

        test = tmp_data[4].to_s
        indexnum = test.index("(")
        delivery = tmp_data[4][0,indexnum]

        test = tmp_data[5].to_s
        indexnum = test.index("(")
        stock = tmp_data[5][0,indexnum]

        transactions = orders.to_i + payments.to_i + order_status.to_i + delivery.to_i + stock.to_i
        @new_csv_data.push transactions
      end
    end
  end
  
  def average_last_10_min()
    start_average_at = @new_csv_data.size - 60
    counter = 0
    total = 0
    @new_csv_data.each do | num |
      if counter >= start_average_at then
        total += num.to_i
      end
      counter += 1
    end
    average = total/60
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

data = ParseTpccOutput.new(ARGV[0], ARGV[1])
data.add_up_transactions()
data.average_last_10_min()
data.write_to_csv()

