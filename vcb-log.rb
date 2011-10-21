#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'date'

CNTR = {
  :total => 0,
  :error => 0,
  :warn => 0,
  :info => 0,
  :debug => 0,
  :apiexception => 0,
  :stacktrace => 0,
  
}

ARGV.collect {|f| File.new(f)}.sort {|a,b| a.mtime <=> b.mtime}.each do |file|
  t0 = t1 = nil
  in_ae = false
  n = 1
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
      if(in_ae || line =~ /ChargebackApiExecutor/)
        CNTR[:apiexception] += 1
        in_ae = true
      else
        CNTR[:stacktrace] += 1
#        puts "#{n}:" + line
      end
    else
      in_ae = false
    end
    n += 1
  end
  dt = DateTime.parse(t1) - DateTime.parse(t0)
  puts sprintf("%-20s: %02d days %02d hrs(%s ~ %s)",file.path,dt, (dt - dt.floor) * 24,t0,t1)
end

[:debug,:info,:warn,:error,:apiexception,:stacktrace,:total].each do |type|
  puts sprintf("%-12s %8d (%d%%)\n",type,CNTR[type],CNTR[type]*100/CNTR[:total])
end
