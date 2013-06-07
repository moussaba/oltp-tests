
class SwrMakeBigDataFile
  def initialize(file_name,size_in_gb, pattern, fill_char)
    @file_name = file_name
    puts @file_name
    @size = size_in_gb.to_i * 2**30
    puts @size
    @pattern = pattern
    puts @pattern
    @fill_char = fill_char
    puts @fill_char

  end
  
  def doit
    file_name = "/backup_data/dd/#{@file_name}"
    f = File.new(@file_name, "w")
    #make n gig file of fill pattern
    file_size = 0
    while file_size < @size.to_i
      #puts "file size is now #{file_size}"
      case @pattern
      when "solid"
        #fills file with all fill char
        tmp = @fill_char * 1024
        #puts tmp
        f.write(tmp)
        file_size += 1024
      when "walking_fill"
        #fills file with 1k of 0s with one fill char rotating through position in file
        #should generate a Meg of data at a pop
        fill_position = 0
        while fill_position < 1024
          tmp = "0" * 1024
          tmp[fill_position] = @fill_char
          fill_position += 1
          #puts tmp
          f.write(tmp)
          file_size += 1024
        end
      when "walking_0"
        #fills file with 1k of fill char with one "0" char rotating through position in file
        #should generate a Meg of data at a pop
        zero_position = 0
        while zero_position < 1024
          tmp = "#{@fill_char}" * 1024
          tmp[zero_position] = "0"
          zero_position += 1
          #puts tmp
          f.write(tmp)
          file_size += 1024
        end
      else
        puts "I seem to be stuck in a loop #{file_size}"
        file_size = @size.to_i
      end
    end
    f.close()
  end
end

create = SwrMakeBigDataFile.new(ARGV[0],ARGV[1],ARGV[2],ARGV[3])
create.doit()