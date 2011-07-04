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
  :input => nil,
  :output => nil,
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb [cmd-options]"
  
  opt.on('-i','--input DIR','Specify root directory of the vCD dump data') do |o|
    options[:input] = o
  end

  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
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
Dir.glob("#{options[:input]}/*-*-*_*-*-*").each do |d|
  outdir = "#{options[:output]}/#{File.basename(d)}"
  next if File.exists? outdir

  vcd = VCloud::VCD.new
  vcd.load(d)
  
  vc = VSphere::VCenter.new
  vc.load(d)

  FileUtils.mkdir_p(outdir)
  open("#{outdir}/VMList.xml",'w') do |f|
    f.puts ERB.new(File.new("template/vcd-report/VMList_Excel.erb").
                   read,0,'>').result(binding)
  end

  vcd.each_org do |org|
    org.each_vdc do |vdc|
      vdc.each_vapp do |vapp|
        dir = "#{outdir}/ORG/#{org.name}/VDC/#{vdc.name}/VAPP/#{vapp.name}"
        FileUtils.mkdir_p(dir) unless File.exists? dir
        open("#{dir}/VAppParams.xml",'w') do |f|
          f.puts ERB.new(File.new("template/vcd-report/VAppParams.erb").
                         read,0,'>').result(binding)
        end
      end
    end
  end
end






