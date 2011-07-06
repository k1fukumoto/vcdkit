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
#  :vcd => ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!'],
  :vcd => ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!'],
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb CMD [options]"

  opt.on('-d','--deploy','CMD: Deploy vApps') do |o|
    options[:command] = :deploy
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

org = vcd.org('CustomerDemo-06')
ci = org.catalog('Demo').catalogitem('test-xp00')
ntwk = org.network('Org Private - CustomerDemo-06')

tasks = (206..215).inject({}) do |h,n|
  h.update(n => org.vdc('Committed - Customer Demo-06').deployVApp(ci,"VCDTEST-#{n}",ntwk))
#  h.update(n => "VCDTEST-#{n}")
end

tasks.keys.sort.each do |n|
  vcd.wait(tasks[n])

  vapp = vcd.org('CustomerDemo-06').vdc('Committed - Customer Demo-06').vapp("VCDTEST-#{n}")
  vm = vapp.vm('test-xp00')

  vcd.wait(vm.customize({'DomainName' => 'SANDI.test',
                        'DomainUserName' => 'Administrator',
                        'DomainUserPassword' => 'Redw00d!',
                        'AdminPassword' => 'Redw00d!',
                        'ComputerName' => "VCDTESTVM-#{n}",
                        }))
  vcd.wait(vm.connectNetwork(0,'Org Private - CustomerDemo-06','DHCP'))
  vcd.wait(vapp.deploy)
end
