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
require 'pp'

#
# Process command args
#
options={
  :vcd => ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!'],
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb CMD [options]"

  opt.on('-d','--deploy','CMD: Deploy vApp from template') do |o|
    options[:dir] = "#{o}/#{ts}"
  end
  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    options[:vcd] = o
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

vcd = VCloud::VCD.new()
vcd.connect(*options[:vcd])
org = vcd.org('Admin')
ci = org.catalog('Public').catalogitem('Windows2003 Standard R2(HDD20GB)')
ntwk = org.network('Admin - Org Private')
vcd.wait(org.vdc('Admin').deployVApp(ci,"WIN2K3-302",ntwk))

vcd = VCloud::VCD.new()
vcd.connect(*options[:vcd])
vapp = vcd.org('Admin').vdc('Admin').vapp('WIN2K3-302')
vm = vapp.vm('Windows2003 Standard R2(HDD20GB)')
vcd.wait(vm.customize('VM-02'))
vcd.wait(vm.connectNetwork(0,'Admin - Org Private','POOL'))
vcd.wait(vapp.deploy)




