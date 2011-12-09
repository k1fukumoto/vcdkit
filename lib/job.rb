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
require 'rubygems'
require 'rufus/scheduler'
require 'vcdkit'

module VCloudJob
  class JobData
    include DataMapper::Resource
    property :id, Serial
    property :job, String
    property :started_at, DateTime
    property :finished_at, DateTime

    def duration
      return '' if (finished_at.nil? || started_at.nil?)
      days = finished_at - started_at
      hrs = (days - days.floor) * 24
      mins = (hrs - hrs.floor) * 60
      secs = (mins - mins.floor) * 60
      sprintf("%2d day %02d:%02d:%02d",
              days.floor,hrs.floor,mins.floor,secs.floor)
    end
  end

  class JobBase
    attr_reader :id
    def initialize
      jd = JobData.new(:job => self.class.name.sub('VCloudJob::',''),
                       :started_at => Time.now)
      jd.save
      @id = jd.id
    end
    def finish
      JobData.get(@id).update(:finished_at => Time.now)
    end
  end

  class VCDDump < JobBase
    def run
      vcd = VCloud::VCD.new(VCloud::DataMapperLogger.new(self.id))
      vcd.connect(*(VCloud::VCD.connectParams)).save(VCloud::Dumper.new(self.id))
      self.finish
    end
  end

  class VCDEX < JobBase
    def run
      vcd = VCloud::VCD.new(VCloud::DataMapperLogger.new(self.id))
      vcd.connect(*(VCloud::VCD.connectParams))
      self.finish
    end
  end

  class Schedule
    include DataMapper::Resource
    property :id, Serial
    property :job, String
    property :schedule, String
  end

  class Scheduler
    def initialize
      @sched = Rufus::Scheduler.start_new
      log = VCloud::DataMapperLogger.new(-1)

      Schedule.all.each do |s|
        _s = s.schedule.split(/\s+/)
        eval <<EOS
@sched.#{_s[0]} '#{_s[1]}' do
  begin
    #{s.job}.new.run
  rescue Exception => e
    log.error('#{s.job} failed ' + e.to_s)
    log.error(e.backtrace)
  end
end
EOS
      end
    end
  end
end
