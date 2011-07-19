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
vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!']

options={
  :vcd => vcd2
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-test.rb CMD [options]"

  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    case o[0]
    when "1"
      options[:vcd] = vcd1
    when "2"
      options[:vcd] = vcd2
    else
      options[:vcd] = o
    end
  end

  opt.on('-d','--deploy','CMD: Deploy vApps for stress testing') do |o|
    options[:command] = :DEPLOY
  end
  opt.on('-u','--undeploy','CMD: Undeploy all vApps') do |o|
    options[:command] = :UNDEPLOY
  end
  opt.on('-n','--num START,BATCHSZ,REPEAT',Array,'Number of auto-deployed vApps') do |o|
    options[:num] = o
  end

  opt.on('-U','--user','CMD: Create users for stress testing') do |o|
    options[:command] = :USER
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

TESTCFG = {
  :DEPLOY => {
    :ORG  => 'CustomerDemo-06',
    :CAT  => 'Demo',
    :CI   => 'SL-XP-00',
    :CIVM => 'SL-XP-00',
    :NTWK => 'Org Private - CustomerDemo-06',
    :VDC  => 'Committed - Customer Demo-06',
    :PREFIX => 'SL-XP-',
  }
}

start = options[:num][0].to_i
sz = options[:num][1].to_i
repeat = options[:num][2].to_i

$log = VCloud::Logger.new(options[:logfile])

case options[:command]
when :DEPLOY
  (1..repeat).each do |n|
    vcd = VCloud::VCD.new()
    vcd.connect(*options[:vcd])

    org = vcd.org(TESTCFG[:DEPLOY][:ORG])
    ci = org.catalog(TESTCFG[:DEPLOY][:CAT]).catalogitem(TESTCFG[:DEPLOY][:CI])
    ntwk = org.network(TESTCFG[:DEPLOY][:NTWK])

    tasks = (start..(start+sz-1)).inject({}) do |h,n|
      h.update(n => org.vdc(TESTCFG[:DEPLOY][:VDC]).deployVApp(ci,"#{TESTCFG[:DEPLOY][:PREFIX]}#{n}",ntwk))
    end
  
    tasks.keys.sort.each do |n|
      vcd.wait(tasks[n])

      vapp = vcd.org(TESTCFG[:DEPLOY][:ORG]).vdc(TESTCFG[:DEPLOY][:VDC]).vapp("#{TESTCFG[:DEPLOY][:PREFIX]}#{n}")
      vm = vapp.vm(TESTCFG[:DEPLOY][:CIVM])

      vcd.wait(vm.customize({'DomainName' => 'sandi.test',
                              'DomainUserName' => 'administrator',
                              'DomainUserPassword' => 'Redw00d!',
                              'AdminPassword' => 'Redw00d!',
                              'ComputerName' => "#{TESTCFG[:DEPLOY][:PREFIX]}#{n}",
                            }))
      vcd.wait(vm.connectNetwork(0,TESTCFG[:DEPLOY][:NTWK],'DHCP'))
      vcd.wait(vapp.deploy)
    end

    start += sz
  end

when :UNDEPLOY
  (1..repeat).each do |n|
    vcd = VCloud::VCD.new()
    vcd.connect(*options[:vcd])
    vdc = vcd.org(TESTCFG[:DEPLOY][:ORG]).vdc(TESTCFG[:DEPLOY][:VDC])

    (start..(start+sz-1)).inject({}) do |h,n|
      vapp = vdc.vapp("#{TESTCFG[:DEPLOY][:PREFIX]}#{n}")
      vcd.wait(vapp.powerOff)
      vcd.wait(vapp.undeploy)

      # Pull the latest vApp XML to ensure the link for delete
      vdc.vapp("#{TESTCFG[:DEPLOY][:PREFIX]}#{n}").delete
    end
    start += sz
  end
end
