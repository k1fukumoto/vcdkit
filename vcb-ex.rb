#!/usr/bin/ruby
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
$: << File.dirname(__FILE__) + "/lib"
require 'optparse'
require 'vcdkit'
require 'vcb'

options={
  :threshold => 5400,
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcb-ex.rb [options]"

  vcopts(options,opt)
  vcbdbopts(options,opt)

  VCloud::Logger.parseopts(opt)
  VCloud::Mailer.parseopts(opt)

  opt.on('','--threshold SECS','Threshold for dc thread timestamp') do |n|
    options[:threshold] = n
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

def find_vms(opts, vmnames)
  ret = []

  vc = VSphere::VCenter.new
  vc.connect(*opts[:vsp])

  vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |c|
      c.host.each do |h|
        h.vm.each do |vm|
          vmnames.each do |vmname|
            next unless vm.name == vmname
            puts "FOUND! #{vmname} on #{h.name}"
          end
        end
      end
    end
  end
end

# find_vms(options,['CGSdhv-868','CGSdhv-869'])

TIMEFORMAT = '%Y-%m-%d %H:%M:%S'

begin
  vcbdb = Chargeback::VCBDB.new
  conn = vcbdb.connect(*options[:vcbdb])
  if conn.nil?
    $log.info("Failed to connect database. Skip the rest of tests.")
    exit(0)
  end

  now = Time.now
  ts_fc = vcbdb.lastFixedCost
  diff = now - ts_fc
  tstr = ts_fc.strftime(TIMEFORMAT)
  fcerror = false
  if(diff > options[:threshold])
    $log.error("Last Fixed Cost #{tstr}(#{diff.to_i} secs old)")
    fcerror = true
  else
    $log.info("Last Fixed Cost #{tstr}(#{diff.to_i} secs old)")
  end

  vcbdb.dcThreads.each do |th|
    ts = th.lastProcessTime
    diff = now - ts
    tstr = ts.strftime(TIMEFORMAT)
    if(diff > options[:threshold] && fcerror)
      $log.error("Last Process Time #{tstr}(#{diff.to_i} secs old): #{th.name}")
    else
      $log.info("Last Process Time #{tstr}(#{diff.to_i} secs old): #{th.name}")
    end
  end

  Chargeback::VCBDB::VM.searchByStartTime(conn,{:t0 => ts_fc,:t1 => Time.now}) do |vm|
    c = vm.created.strftime('%Y-%m-%d %H:%M:%S')
    d = vm.deleted.strftime('%Y-%m-%d %H:%M:%S')
    $log.info("Unprocessed VM found: #{vm.org}/#{vm.vapp}/#{vm.name}(#{vm.heid}) #{c} ~ #{d}")
  end

rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  $log.error("vcb-ex failed: #{e}")
  $log.error(e.backtrace)

ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcbdb = options[:vcbdb][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcb-ex.log' => File.read($log.temp.path)},
               binding)
  end
end
exit ($log.errors + $log.warns)
