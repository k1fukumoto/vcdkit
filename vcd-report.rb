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
vcd = VCloud::VCD.new
vcd.load(options[:input])

vc = VSphere::VCenter.new
vc.load(options[:input])

FileUtils.mkdir_p(options[:output]) unless File.exists? options[:output]
Dir.glob("template/vcd-report_*.erb").each do |tmpl|
  tmpl =~ /vcd-report_(.*)\.erb/
  open("#{options[:output]}/#{$1}.xml",'w') do |f|
    f.puts ERB.new(File.new(tmpl).read,0,'>').result(binding)
  end
end







