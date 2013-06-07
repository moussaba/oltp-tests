# program: blktrace2dataset.rb
# usage:   ruby blktrace2dataset.rb drive name, ReadBlockNosFilename, WriteBlockNosFilename

drive_name = ARGV[0]

#-------------------------------------
# structures used for organizing data
#-------------------------------------
class PerIo <
  Struct.new(:q_time, :g_time, :i_time, :d_time, :c_time, :k_bytes, :c_address)
end

class DataSet <
  Struct.new( :q_time,:d_time,:c_time,:k_bytes,:address,:drive_name,:rw,:active_reads,:active_writes,:q_depth,:q2c,:q2d,:d2c,:iops)
end

#--------------------------------------------------
# run blkparse and btt on the blktrace data files
#--------------------------------------------------
result = `blkparse -i #{drive_name} -d #{drive_name}.bin -o /dev/null`
result = `btt -i #{drive_name}.bin -B bnos -Q q_depth -p per_io`

#-------------------------------------
# use data in per_io file to construct
# io by io data set
#-------------------------------------
@data_set = Array.new

state = "start"
@p = PerIo.new
inf = File.open("per_io", "r")
line = "duh"  #anything but nil
while line != nil do
  line = inf.gets
  case state
  when "start"
    if line.include?("-----------------------") then
      #puts "----------------------"
      state = "get q data"
    end
  when "get q data"
    if line == nil then break end
    if line.include?(":")
      tmp = line.split(" ")
      @p.q_time = tmp[2].to_f
      #puts "q time #{@p.q_time}"
      state = "get g data"
    end
  when "get g data"
    tmp = line.split(" ")
    @p.g_time = tmp[0].to_f
    #puts "g time #{@p.g_time}"
    state = "get i data"
  when "get i data"
    tmp = line.split(" ")
    @p.i_time = tmp[0].to_f
    #puts "i time #{@p.i_time}"
    state = "get d data"
  when "get d data"
    tmp = line.split(" ")
    @p.d_time = tmp[0].to_f
    #puts "d time #{@p.d_time}"
    state = "get c data"
  when "get c data"
    tmp = line.split(" ")
    @p.c_time = tmp[0].to_f
    tmp = tmp[2]
    if tmp == nil then
      @p.c_address = 0
      @p.k_bytes = 0
    else
      tmp = tmp.split("+")
      @p.c_address = tmp[0].to_i
      #puts "c address #{@p.c_address}"
      tmp = tmp[1].to_i * 512 / 1024 #converting from 512 byte blocks
      @p.k_bytes = tmp
      #puts "k bytes #{@p.k_bytes}"
    end
    ds = DataSet.new
    ds.q_time = @p.q_time
    ds.d_time = @p.d_time
    ds.c_time = @p.c_time
    ds.k_bytes = @p.k_bytes
    ds.address = @p.c_address
    ds.drive_name = drive_name
    ds.q2c = ds.c_time - ds.q_time
    ds.q2d = ds.d_time - ds.q_time
    ds.d2c = ds.c_time - ds.d_time
    @data_set.push(ds)
    @p = PerIo.new
    state = "start"
  end
end
inf.close

#-----------------------------------------
# data set is sometimes out of order so
# sort it  - needed for remaining steps
#-----------------------------------------
@data_set.sort! { |a,b| a.q_time <=> b.q_time }

#----------------------------------
# load in bnos read and write files
#----------------------------------

#have to figure out how to get this from the directory and not passed in on the cmd line
dir = `ls`
puts dir
#readfile = ARGV[1]
#writefile = ARGV[2]

readf = File.open(readfile,"r")
writef = File.open(writefile,"r")

readrec = readf.gets
readrec = readrec.split(" ")
writerec = writef.gets
writerec = writerec.split(" ")

foundEOF = FALSE

#---------------------------------
# sort out reads and writes
#---------------------------------
@data_set.each do |io|
  while readrec[0].to_f < io.d_time
    readrec = readf.gets
    if readrec == NIL then 
      foundEOF = TRUE
      break;
    else
      readrec = readrec.split(" ")
    end
  end

  while writerec[0].to_f < io.d_time
    writerec = writef.gets
    if writerec == NIL then
      foundEOF = TRUE
      break;
    else
      writerec = writerec.split(" ")
    end
  end
  
  if foundEOF == TRUE then
    break;
  else
    if readrec[0].to_f == io.d_time then
      io.rw = "r"
    elsif writerec[0].to_f == io.d_time then
      io.rw = "w"
    else
      io.rw = "d" #for not found "dud"
    end
  end
end

readf.close
writef.close

#-----------------------------
# calc iops
#-----------------------------

@io_count = 0
@avg_size = 25
@io_arr = Array.new

@data_set.each do |io|
  @io_count += 1
  @io_arr.push(io.d_time)
  if @io_count > @avg_size then
    @io_arr.shift
    elapsed_time = @io_arr[@avg_size -1] + io.d2c - @io_arr[0]
    if elapsed_time < 0 then
      io.iops = 0
    else
      io.iops = @avg_size/elapsed_time 
    end
  else
    io.iops = 0
  end
end

#-------------------------------------
# calc active reads/writes and q_depth
#-------------------------------------

read_times = Array.new
write_times = Array.new

@data_set.each do |io|
  if io.rw == "r" then
    read_times.push(io.c_time)
  elsif io.rw == "w" then
    write_times.push(io.c_time)
  end
  
  r = read_times[0]
  while r != NIL and r < io.q_time # r!= NIL gets tested first
    read_times.shift
    r = read_times[0]
  end
      
  w = write_times[0] and 
  while w != NIL and w < io.q_time # w!= NIL gets tested first
    write_times.shift
    w = write_times[0]
  end

  io.active_reads = read_times.length
  io.active_writes = write_times.length
  io.q_depth = io.active_reads + io.active_writes
end

csv_file_header = "q_time, d_time, c_time, k_bytes, address, drive_name, rw, active_reads, active_writes, q_depth, q2c, q2d, d2c, iops"
outf = File.open("data_set.csv", "w")
outf.puts csv_file_header

@data_set.each do |io|
  output_string = "#{io.q_time},#{io.d_time},#{io.c_time},#{io.k_bytes},#{io.address},#{io.drive_name},"
  output_string += "#{io.rw},#{io.active_reads},#{io.active_writes},#{io.q_depth},#{io.q2c},#{io.q2d},#{io.d2c},#{io.iops}"
  outf.puts output_string
end
outf.close
    
 