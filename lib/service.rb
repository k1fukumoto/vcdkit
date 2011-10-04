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
require 'tempfile'
require 'pony'

module VCloud
  class Logger
    attr_reader :temp,:errors

    def Logger.parseopts(opt)
      opt.on('-l','--logfile LOGFILEPATH','Log file name') do |path|
        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.exists? dir
        $log.add_logger(::Logger.new(path,10,20480000))
        # keep last 10 generations, cap size at 20MB
      end
      opt.on('-t','--tempfile','Output log to temporary file') do |o|
        $log.add_logger(Tempfile.new(self.class.name))
      end

    end

    def initialize
      @loggers = []
      @errors = 0
      self.add_logger(::Logger.new(STDOUT))
    end

    def add_logger(l)
      if(l.class == Tempfile)
        @temp = l
        l = ::Logger.new(@temp.path)
      end

      l.formatter = proc {|sev,time,prog,msg|
        ts = time.strftime('%Y-%m-%d %H:%M:%S')
        "#{ts} | #{sev} | #{msg}\n"
      }
      @loggers.push(l)
    end

    def info(msg)
      @loggers.each {|l| l.info(msg)}
    end
    def error(msg)
      @errors += 1
      @loggers.each {|l| l.error(msg)}
    end
    def warn(msg)
      @loggers.each {|l| l.warn(msg)}
    end

    def close
      if(@temp)
        self.info("Deleting temporary log file: #{@temp.path}")
        @temp.close
        @temp.unlink
      end
    end
  end

  class Mailer
    def Mailer.parseopts(opt)
      opt.on('-m','--mailconf CONFFILE','Mailer configuration file name') do |c|
        $mail.configure(c)
      end
    end

    def configure(conf)
      @conf = REXML::Document.new(File.new(conf))
    end

    def Mailer.build(template,bind)
      ERB.new(template.gsub('{%','<%').gsub('%}','%>')).result(bind)
    end

    def send(attachments,bind)
      e = @conf.elements['/mailerconf'].elements

      Pony.mail(:to => e.collect('./to') {|to| to.text}.join(','),
                :from => e['./from'].text,

                :subject => Mailer.build(e['./subject'].text,bind),
                :body => Mailer.build(e['./body'].text,bind),
                :attachments => attachments,

                :via => :smtp,
                :via_options => { 
                  :address => e['./smtp/host'].text,
                  :port => e['./smtp/port'].text,
                  :user_name => e['./smtp/user'].text,
                  :password => e['./smtp/password'].text,
                  :authentication => e['./smtp/authentication'].text,
                  :domain => "localhost.localdomain",
                })
    end
  end
end

