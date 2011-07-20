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
options = {
  :input => "./data/vcd-dump",
  :output => "./data/vcd-report",
  :target => :all,
}

vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!']

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb [cmd-options]"
  
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

  opt.on('-i','--input DIR','Specify root directory of the vCD dump data') do |o|
    options[:input] = o
  end
  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Create report for specified vApp') do |o|
    options[:target] = o
  end
  opt.on('-A','--all','Create report for entire dump tree') do |o|
    options[:target] = :all
  end
  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
  end
  opt.on('-f','--force','Force to recreate reports to exisiting tree') do |o|
    options[:force] = true
  end

  opt.on('-l','--logfile LOGFILEPATH','Log file name') do |o|
    options[:logfile] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("--input") if options[:input].nil?
  raise OptionParser::MissingArgument.new("--output") if options[:output].nil?
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

#
# MAIN
#
$log = VCloud::Logger.new(options[:logfile])
ot = options[:target]

if(options[:vcd])

  vcd = VCloud::VCD.new
  vcd.connect(*options[:vcd])

  if(ot == :all)
    vcd.saveparam("#{options[:output]}/#{options[:tree]}")
  elsif(ot.size == 3)
    vcd.org(ot[0]).vdc(ot[1]).vapp(ot[2]).saveparam("#{options[:output]}/#{options[:tree]}")
  else
    $log.error("vcd-report invalid command options")
  end

else # Load dump tree from directory

  subdir = options[:tree] || "*"
  Dir.glob("#{options[:input]}/#{subdir}").each do |d|
    outdir = "#{options[:output]}/#{File.basename(d)}"
    next if (File.exists?(outdir) && !options[:force])

    begin

      vcd = VCloud::VCD.new
      if(ot == :all)
        vcd.load(d).saveparam(outdir)
        
        vc = VSphere::VCenter.new
        vc.load(d)

        FileUtils.mkdir_p(outdir)
        open("#{outdir}/VMList.xml",'w') do |f|
          f.puts ERB.new(File.new("template/vcd-report/VMList_Excel.erb").
                         read,0,'>').result(binding)
        end

      elsif(ot.size == 3)
        VCloud::VApp.new(*ot).load(d).saveparam(outdir)
      end

    rescue Exception => e
      $log.error("vcd-report failed: #{e}")
      $log.error(e.backtrace)
    end
  end
end
