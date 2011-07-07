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

  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    options[:vcd] = o
  end
  opt.on('-d','--deploy','CMD: Deploy vApps for stress testing') do |o|
    options[:command] = :deploy
  end
  opt.on('-u','--undeploy','CMD: Undeploy all vApps') do |o|
    options[:command] = :undeploy
  end
  opt.on('-n','--num START,BATCHSZ,REPEAT',Array,'Number of auto-deployed vApps') do |o|
    options[:num] = o
  end
  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  if (options[:command].nil?)
    raise OptionParser::MissingArgument.new("CMD")
  end
  if (options[:num].nil? || options[:num].size != 3)
    raise OptionParser::MissingArgument.new("--num") 
  end
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

TEST01_ORG  = 'CustomerDemo-06'
TEST01_CAT  = 'Demo'
TEST01_CI   = 'SL-XP-00'
TEST01_CIVM = 'SL-XP-00'
TEST01_NTWK = 'Org Private - CustomerDemo-06'
TEST01_VDC  = 'Committed - Customer Demo-06'
TEST01_PREFIX = 'SL-XP-'

vcd = VCloud::VCD.new()
vcd.connect(*options[:vcd])

start = options[:num][0].to_i
sz = options[:num][1].to_i
repeat = options[:num][2].to_i

case options[:command]
when :deploy
  org = vcd.org(TEST01_ORG)
  ci = org.catalog(TEST01_CAT).catalogitem(TEST01_CI)
  ntwk = org.network(TEST01_NTWK)

  (1..repeat).each do |n|

    tasks = (start..(start+sz-1)).inject({}) do |h,n|
      h.update(n => org.vdc(TEST01_VDC).deployVApp(ci,"#{TEST01_PREFIX}#{n}",ntwk))
    end
  
    tasks.keys.sort.each do |n|
      vcd.wait(tasks[n])

      vapp = vcd.org(TEST01_ORG).vdc(TEST01_VDC).vapp("#{TEST01_PREFIX}#{n}")
      vm = vapp.vm(TEST01_CIVM)

      vcd.wait(vm.customize({'DomainName' => 'sandi.test',
                              'DomainUserName' => 'administrator',
                              'DomainUserPassword' => 'Redw00d!',
                              'AdminPassword' => 'Redw00d!',
                              'ComputerName' => "#{TEST01_PREFIX}#{n}",
                            }))
      vcd.wait(vm.connectNetwork(0,TEST01_NTWK,'DHCP'))
      vcd.wait(vapp.deploy)
    end

    start += sz
  end

when :undeploy
  (1..repeat).each do |n|
    (start..(start+sz-1)).inject({}) do |h,n|
      vapp = vcd.org(TEST01_ORG).vdc(TEST01_VDC).vapp("#{TEST01_PREFIX}#{n}")
      
      vcd.wait(vapp.powerOff)
      vcd.wait(vapp.undeploy)
    end
    start += sz
  end
end
