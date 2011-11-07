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

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcb-vm.rb [options]"

  vcbdbopts(options,opt)

  VCloud::Logger.parseopts(opt)

  opt.on('-s','--starttime T0,T1',Array,'Start time range') do |r|
    options[:starttime] = r
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

TIMEFORMAT = '%Y-%m-%d %H:%M:%S'

begin
  vcbdb = Chargeback::VCBDB.new
  conn = vcbdb.connect(*options[:vcbdb])
  if conn.nil?
    raise "Failed to connect database. Exiting."
  end

  opts = {
    :t0 => DateTime.parse(options[:starttime][0]),
    :t1 => DateTime.parse(options[:starttime][1]),
  }

  missed_vmic = []
  Chargeback::VCBDB::VM.searchByStartTime(conn,opts) do |vm|
    c = vm.created.strftime(TIMEFORMAT)
    d = vm.deleted.strftime(TIMEFORMAT)

#    next if vm.org =~ /Admin/
#    next if vm.vdc =~ /Committed/

    puts "\n#{vm.heid}: #{vm.org} | #{vm.vdc} | #{vm.vapp} | #{vm.name}"
    puts "  Lifetime: #{c} ~ #{d}"
    vm.each_vmicost do |vmic|
      match = false
      vm.each_fixedcost do |fc|
        if (fc == vmic)
          match = true
          break
        end
      end
      if match
        puts "  Processed VMIC: #{vmic}" 
      else
        missed_vmic.push(vmic)
        puts "* Missing VMIC:   #{vmic}" 
      end
    end
  end

  if (missed_vmic.size > 0)
    sql = missed_vmic.collect{|v| v.insert}.join('')
    puts "[ VMIC Inserts ]"
    puts "#{sql}"
    print "Execute SQL(yN)? "; a = gets
    if(a =~ /[yY]/)
      missed_vmic.each do |v|
        n = conn.exec(v.insert)
      end
      conn.exec("COMMIT")
    end
  end

rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  $log.error("vcb-vm failed: #{e}")
  $log.error(e.backtrace)

ensure
end
exit ($log.errors + $log.warns)
