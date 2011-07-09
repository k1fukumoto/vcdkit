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
#  :vcd => ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!'],
  :vcd => ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!'],
#  :vsp => ['172.16.180.30','vcdadmin','vmware1!']
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-dump.rb [options]"

  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    options[:vcd] = o
  end
  opt.on('-V','--vsp HOST,USER,PASS',Array,'vCenter login parameters') do |o|
    options[:vsp] = o
  end

  opt.on('-d','--dir DIR','Root directory of the dump data') do |o|
    options[:dir] = o
  end
  opt.on('-a','--all','Dump all data') do |o|
    options[:target] = :all
  end
  opt.on('-t','--target ORG,VDC,VAPP,VM',Array,'Dump target object') do |o|
    options[:target] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  if (options[:target].nil?)
    raise OptionParser::MissingArgument.new("--target")
  end
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

vc = nil
if (options[:vsp])
  vc = VSphere::VCenter.new
  vc.connect(*options[:vsp])
end

ot = options[:target]
if(ot == :all)
  vcd.save(options[:dir])
  vc.save(options[:dir]) unless vc.nil?

elsif(ot.size == 3)
  vapp = vcd.org(ot[0]).vdc(ot[1]).vapp(ot[2])
  puts vapp.xml
else
  raise "Wrong arguments: #{ot}"
end
