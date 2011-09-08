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
require 'date'
require 'vcdkit'

options = {
  :input => "#{$VCDKIT}/data/vcd-report",
  :output => "#{$VCDKIT}/data/vcd-trend",
  :target => :all,
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-report.rb [cmd-options]"
  
  opt.on('-v','--vcd HOST,ORG,USER',Array,'vCD login parameters') do |o|
    case o[0]
    when "1"
      options[:vcd] = $VCD1
    when "2"
      options[:vcd] = $VCD2
    else
      options[:vcd] = o
    end
  end

  opt.on('-i','--input DIR','Specify root directory of the report data') do |o|
    options[:input] = o
  end
  opt.on('-o','--output DIR','Specify directory for trend data') do |o|
    options[:output] = o
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
rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])

# Determine target report data range
pm = (Date.parse(Time.now.to_s) << 1) # previous month
first = Date.civil(pm.year,pm.month,1) 
last = Date.civil(pm.year,pm.month,-1)

repdirs = Dir.glob("#{options[:input]}/*-*-*_*-*-*").select do |d| 
  if (File.directory?(d))
    d =~ /\/(\d{4})-(\d{2})-(\d{2})/
    dt = Date.civil($1.to_i,$2.to_i,$3.to_i)
    first <= dt && dt <= last
  else
    false
  end
end.sort

outdir = "#{options[:output]}/#{File.basename(repdirs.first)}__#{File.basename(repdirs.last)}"
FileUtils.mkdir_p(outdir) unless File.exists? outdir

data = {}
repdirs.each do |d|
  next unless File.exists?("#{d}/VMList.xml")
  doc = REXML::Document.new(File.new("#{d}/VMList.xml").read)
  tree = File.basename(d)
  $log.info("Start processing '#{tree}'")
  r = -1
  doc.elements.each('//Row') do |row|
    r += 1
    next if r == 0

    c = 0
    rd = []
    row.elements.each('./Cell') do |cell|
      rd[c] = cell.elements['./Data'].text
      c += 1
    end
    next if rd[6].nil?

    data[rd[1]] = {} if (data[rd[1]].nil?)
    data[rd[1]][rd[2]] = {} if (data[rd[1]][rd[2]].nil?)
    data[rd[1]][rd[2]][rd[6]] = {} if (data[rd[1]][rd[2]][rd[6]].nil?)
    data[rd[1]][rd[2]][rd[6]][tree] = 0 if (data[rd[1]][rd[2]][rd[6]][tree].nil?)

    data[rd[1]][rd[2]][rd[6]][tree] += 1
  end
end

$log.info("Saving GuestList.xml...")
open("#{outdir}/GuestList.xml",'w') do |f|
  f.puts ERB.new(File.new("template/vcd-trend/GuestList_Excel.erb").
                 read,0,'>').result(binding)
end

$log.info("Sending Emails...")
require 'pony'
hname = `hostname`.chomp
vcdhost = options[:vcd][0]

subject = "vCDC guest OS usage report: [#{vcdhost}] #{pm.year}/#{pm.month}"
body = <<EOS
VCD: #{vcdhost}
REPORT CREATED: #{Time.now}
EOS

Pony.mail(:to => 'k1fukumoto@gmail.com',
          :from => "#{hname}@dhs.jtidc.jp", 

          :subject => subject,
          :body => body,

          :attachments => {
            "GuestList.xml" =>
            File.read("#{outdir}/GuestList.xml")
          },

          :via => :smtp,
          :via_options => { 
            :address              => '10.121.0.113',
            :domain               => "localhost.localdomain"
          })
$log.info("Emails sent")

