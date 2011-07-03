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
ts=Time.now.strftime('%Y-%m-%d_%H-%M-%S')
options={
  :dir => "./VCDDUMP/#{ts}",
  :vcd => ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!'],
#  :vsp => ['172.16.180.30','vcdadmin','vmware1!']
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-dump.rb [options]"

  opt.on('-d','--dir DIR','Root directory of the dump data') do |o|
    options[:dir] = "#{o}/#{ts}"
  end
  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    options[:vcd] = o
  end
  opt.on('-V','--vsp HOST,USER,PASS',Array,'vCenter login parameters') do |o|
    options[:vsp] = o
  end
  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

#
# MAIN
#
vcd = VCloud::VCD.new
vcd.connect(*options[:vcd])
vcd.save(options[:dir])

if (options[:vsp])
  vc = VSphere::VCenter.new
  vc.connect(*options[:vsp])
  vc.save(options[:dir])
end
