#!/usr/bin/ruby
require 'date'

CNTR = {
  :total => 0,
  :error => 0,
  :warn => 0,
  :info => 0,
  :debug => 0,
  :stacktrace_apiexception => 0,
  :stacktrace_other => 0,
  
}

ARGV.collect do |f| 
  File.new(f)
end.sort do |a,b| 
  a.path =~ /\.(\d*)$/; at = $1 || 0
  b.path =~ /\.(\d*)$/; bt = $1 || 0
  bt.to_i <=> at.to_i
end.each do |file|
  t0 = t1 = nil
  in_ae = false
  n = 1
  prev_line = nil
  while(line = file.gets)
    if(line =~ /^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/)
      t1 = $1
      t0 = t1 unless t0
    end
    CNTR[:total] += 1
    CNTR[:error] += 1 if line =~ /ERROR/
    CNTR[:warn] += 1 if line =~ /WARN/
    CNTR[:info] += 1 if line =~ /INFO/
    CNTR[:debug] += 1 if line =~ /DEBUG/
    if(line =~ /^\tat/)
      if(in_ae || 
         line =~ /ChargebackApiExecutor/ ||
         prev_line =~ /ChargebackApiFailedException/ )
        CNTR[:stacktrace_apiexception] += 1
        in_ae = true
      else
        CNTR[:stacktrace_other] += 1
      end
    else
      in_ae = false
    end
    n += 1
    prev_line = line
  end
  days = DateTime.parse(t1) - DateTime.parse(t0)
  hrs = (days - days.floor) * 24
  mins = (hrs - hrs.floor) * 60
  puts sprintf("%-16s(%-2dMB):%2d day %02d:%02d (%s ~ %s)",
               file.path,File.size(file)/1024/1024,days.floor,hrs.floor,mins.floor,t0,t1)
end

[:debug,:info,:warn,:error,:stacktrace_apiexception,:stacktrace_other,:total].each do |type|
  puts sprintf("%-24s %8d (%3d%%)\n",type,CNTR[type],CNTR[type]*100/CNTR[:total])
end
