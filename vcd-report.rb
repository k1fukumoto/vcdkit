#!/usr/bin/ruby -I./lib
#######################################################################################
#
# Copyright 2011 Kaoru Fukumoto All Rights Reserved
#
# You may freely use and redistribute this script as long as this 
# copyright notice remains intact 
#
#
# DISCLAIMER. THIS SCRIPT IS PROVIDED TO YOU "AS IS" WITHOUT WARRANTIES OR CONDITIONS 
# OF ANY KIND, WHETHER ORAL OR WRITTEN, EXPRESS OR IMPLIED. THE AUTHOR SPECIFICALLY 
# DISCLAIMS ANY IMPLIED WARRANTIES OR CONDITIONS OF MERCHANTABILITY, SATISFACTORY 
# QUALITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. 
#
#######################################################################################
require 'optparse'
require 'vcdkit'

#
# Process command args
#
options = {
  :input => "./data/vcd-dump",
  :output => "./data/vcd-report",
  :target => :all,
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb [cmd-options]"
  
  opt.on('-i','--input DIR','Specify root directory of the vCD dump data') do |o|
    options[:input] = o
  end
  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Create report for specified vApp') do |o|
    options[:target] = o
  end
  opt.on('-A','--all','Create report for entire dump tree') do |o|
    options[:target] = :all
  end
  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
  end
  opt.on('-f','--force','Force to recreate reports to exisiting tree') do |o|
    options[:force] = true
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("--input") if options[:input].nil?
  raise OptionParser::MissingArgument.new("--output") if options[:output].nil?
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

#
# MAIN
#
$log = VCloud::Logger.new(options[:logfile])

subdir = options[:tree] || "*"
Dir.glob("#{options[:input]}/#{subdir}").each do |d|
  outdir = "#{options[:output]}/#{File.basename(d)}"
  next if (File.exists?(outdir) && !options[:force])

  vcd = VCloud::VCD.new

  ot = options[:target]
  if(ot == :all)
    vcd.load(d)
  
#  vc = VSphere::VCenter.new
#  vc.load(d)

#  FileUtils.mkdir_p(outdir)
#  open("#{outdir}/VMList.xml",'w') do |f|
#    f.puts ERB.new(File.new("template/vcd-report/VMList_Excel.erb").
#                   read,0,'>').result(binding)
#  end

    vcd.saveparam(outdir)

  elsif(ot.size == 3)
    vcd.load(d,*ot).saveparam("#{outdir}/ORG/#{ot[0]}/VDC/#{ot[1]}/VAPP/#{ot[2]}")
  end
end
