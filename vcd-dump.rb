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
  :vcd => 'vcd.vhost.ultina.jp',
  :org => 'System',
  :user => 'vcdadminl',
  :pass => 'Redw00d!',
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-dump.rb [options]"

  opt.on('-d','--dir DIR','Specify root directory of the dump data') do |o|
    options[:dir] = "#{o}/#{ts}"
  end
  opt.on('-v','--vcd HOST','Specify hostname or IP address of vCloud Director') do |o|
    options[:vcd] = o
  end
  opt.on('-o','--org ORG','Specify organization name') do |o|
    options[:org] = o
  end
  opt.on('-u','--user USER','Specify user name') do |o|
    options[:user] = o
  end
  opt.on('-p','--pass PASSWORD','Specify password') do |o|
    options[:pass] = o
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
vcd.connect(options[:vcd],options[:org],options[:user],options[:pass])
vcd.save(options[:dir])
#VMExt::VSphere.new(vcd).dump("../VCDDUMP")




