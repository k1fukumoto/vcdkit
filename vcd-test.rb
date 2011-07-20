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
  opt.banner = "Usage: vcd-test.rb -T TESTNUMBER CMD [options]"

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

  opt.on('-T','--test TESTNUMBER','Test number') do |o|
    options[:test] = o.to_i
  end

  opt.on('-s','--setup','Setup the test environment') do |o|
    options[:command] = :SETUP
  end
  opt.on('-t','--teardown','Tear-down the test environment') do |o|
    options[:command] = :TEARDOWN
  end

  opt.on('-n','--num START,BATCHSZ,REPEAT',Array,'Number of auto-deployed objects') do |o|
    options[:num] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("CMD") if (options[:command].nil?)
  raise OptionParser::MissingArgument.new("TEST") if(options[:test].nil?)
  if (options[:num].nil? || options[:num].size != 3)
    raise OptionParser::MissingArgument.new("--num") 
  end
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

TESTCFG = {
  1 => {
    :ORG  => 'CustomerDemo-06',
    :CAT  => 'Demo',
    :CI   => 'SL-XP-00',
    :CIVM => 'SL-XP-00',
    :NTWK => 'Org Private - CustomerDemo-06',
    :VDC  => 'Committed - Customer Demo-06',
    :PREFIX => 'SL-XP-',
  },
  2 => {
    :ORG  => 'Admin',
    :CAT  => 'Public',
    :CI   => 'WIN2003-STD-R2-32',
    :CIVM => 'WIN2003-STD-R2-32',
    :NTWK => 'Org Private - Admin',
    :VDC  => 'Basic - Admin',
    :PREFIX => 'WIN2K3-',
  },
  3 => {
    :ORG  => 'VMTest',
    :CAT  => 'Test',
    :CI   => 'WIN2003-STD-R2-32',
    :CIVM => 'WIN2003-STD-R2-32',
    :NTWK => 'Org Private - VMTest',
    :VDC  => 'Basic - VMTest',
    :PREFIX => 'CBSCALE-',
  },
  10 => {
    :ORG  => 'VMTest',
    :ROLE  => 'vApp Author',
    :PREFIX => 'USER-',
  }
}

start = options[:num][0].to_i
sz = options[:num][1].to_i
repeat = options[:num][2].to_i

$log = VCloud::Logger.new(options[:logfile])
cfg = TESTCFG[options[:test]]

case options[:test]
when 1..3
  case options[:command]
  when :SETUP
    (1..repeat).each do |n|
      vcd = VCloud::VCD.new()
      vcd.connect(*options[:vcd])

      org = vcd.org(cfg[:ORG])
      ci = org.catalog(cfg[:CAT]).catalogitem(cfg[:CI])
      ntwk = org.network(cfg[:NTWK])

      tasks = (start..(start+sz-1)).inject({}) do |h,n|
        h.update(n => org.vdc(cfg[:VDC]).deployVApp(ci,"#{cfg[:PREFIX]}#{n}",ntwk))
      end
      
      tasks.keys.sort.each do |n|
        vcd.wait(tasks[n])

        vapp = vcd.org(cfg[:ORG]).vdc(cfg[:VDC]).vapp("#{cfg[:PREFIX]}#{n}")
        vm = vapp.vm(cfg[:CIVM])

        vcd.wait(vm.customize({
                                # 'DomainName' => 'sandi.test',
                                # 'DomainUserName' => 'administrator',
                                # 'DomainUserPassword' => 'Redw00d!',
                                'AdminPassword' => 'Redw00d!',
                                'ComputerName' => "#{cfg[:PREFIX]}#{n}",
                              }))
        vcd.wait(vm.connectNetwork(0,cfg[:NTWK],'POOL'))
        vcd.wait(vapp.deploy)
      end
      start += sz
    end
  when :TEARDOWN
    (1..repeat).each do |n|
      vcd = VCloud::VCD.new()
      vcd.connect(*options[:vcd])
      vdc = vcd.org(cfg[:ORG]).vdc(cfg[:VDC])

      (start..(start+sz-1)).inject({}) do |h,n|
        vapp = vdc.vapp("#{cfg[:PREFIX]}#{n}")
        vcd.wait(vapp.powerOff)
        vcd.wait(vapp.undeploy)

        # Pull the latest vApp XML to ensure the link for delete
        vdc.vapp("#{cfg[:PREFIX]}#{n}").delete
      end
      start += sz
    end
  end

when 10
  case options[:command]
  when :SETUP
    (1..repeat).each do |n|
      vcd = VCloud::VCD.new()
      vcd.connect(*options[:vcd])

      org = vcd.org(cfg[:ORG])
      role = vcd.role(cfg[:ROLE])
      tasks = (start..(start+sz-1)).each do |n|
        org.add_user("#{cfg[:PREFIX]}#{n}",role)
      end

      start += sz
    end
  when :TEARDOWN
    (1..repeat).each do |n|
      vcd = VCloud::VCD.new()
      vcd.connect(*options[:vcd])

      org = vcd.org(cfg[:ORG])
      tasks = (start..(start+sz-1)).each do |n|
        user = org.user("#{cfg[:PREFIX]}#{n}")
        user.disable
        user.delete
      end

      start += sz
    end
  end
end
