#!/usr/bin/env ruby

require 'rubygems'
require 'sinatra'
require 'json'
require 'yaml'
require 'data_mapper'

$: << File.dirname(__FILE__) + "/lib"
require 'vcdkit'
require 'job'

class VCAPServiceConf
  attr_reader :dbparams
  def initialize
    @services = JSON.parse(ENV['VCAP_SERVICES'])
    @dbparams = @services.keys.select do |svc|
      svc =~ /redis/i || svc =~ /mysql/i 
    end.inject({}) do |h,key|
      h.update(key => @services[key].first['credentials'])
      h
    end
  end
end

configure do
  @@services = VCAPServiceConf.new
  dbc = @@services.dbparams['mysql-5.1']

  DataMapper.finalize
  DataMapper::setup(:default,
                    { :adapter => 'mysql',
                      :host => dbc['host'],
                      :database => dbc['name'],
                      :username => dbc['username'],
                      :password => dbc['password'],
                    })

  DataMapper.auto_migrate!

  YAML::load(File.new(File.dirname(__FILE__) + 
                      "/conf/vcloud_servers.yml").read).each do |r|
    VCloudServers.create(:application => r['application'],
                         :host => r['host'],
                         :account => r['account'],
                         :password => r['password'])
  end

  YAML::load(File.new(File.dirname(__FILE__) + 
                      "/conf/job_schedule.yml").read).each do |r|
    VCloudJob::Schedule.create(:job => r['job'],
                               :schedule => r['schedule'])
  end

  VCloudJob::Scheduler.new
end

get '/' do
  erb :index
end

get '/dump/:id' do
  erb :dump
end

post '/vcloud_servers' do
  params.keys.join("<BR>")
end

get '/vapp/:id' do
  content_type 'text/xml'
  DumpData.get(params[:id]).xml
end

get '/job/:name' do
  erb :job
end

get '/log/:jobid' do
  erb :log
end

get '/setting' do
  erb :setting
end
