# -*- coding: utf-8 -*-
######################################################################################
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
require 'rbvmomi'
require 'erb'

#
# VSphere
#
module VSphere
  class Media
    attr_reader :path,:vdc,:datastore,:org
    def load(node)
      @path = node.elements["./@path"].value
      @vdc = node.elements["./VDC/@path"].value
      @datastore = node.elements["./Datastore/@path"].value
      @org = node.elements["./Organization/@path"].value
    end
  end

  class Vm 
    attr_reader :name,:esx,:datastore,:guestFullName,:guestFamily

    def initialize
      # ensure never returns nil for attributes
      @name = @esx = @datastore = @guestFullName = @guestFamily = ''
    end

    def load(node)
      @name = node.attributes['name']
      @esx = node.elements["../@name"].value
      
      @guestFullName = node.elements["./Guest/@name"].value
      @guestFamily = node.elements["./Guest/@family"].value


      ds = node.elements["./Datastore/@name"]
      @datastore = ""
      @datastore = ds.value unless ds.nil?
    end
  end

  class DatastoreBrowser
    def initialize(ds)
      @datastore = ds
    end

    def search(path)
      spec = RbVmomi::VIM::HostDatastoreBrowserSearchSpec.new
      spec.query = [RbVmomi::VIM::FileQuery.new]
      begin 
        task = @datastore.browser.SearchDatastoreSubFolders_Task('datastorePath' => path,'searchSpec' => spec)
        task.wait_for_completion
        task.info.result
      rescue Exception => e
        []
      end
    end

    def each_media()
      self.search("[#{@datastore.info.name}] ").each do |f|
        orgpath = f.folderPath
        next unless (orgpath =~ /.*\/media\/(\d+-org)/ || # 1.0
                     orgpath =~ /.*\/media\/(org \([0-9a-f\-]+\))/)   # 1.5
        org = $1

        self.search(orgpath).each do |f|
          vdcpath = f.folderPath
          next unless (vdcpath =~ /(\d+-vdc)/ || # 1.0
                       vdcpath =~ /(vdc \([0-9a-f\-]+\))/) # 1.5
          vdc = $1

          self.search(vdcpath).each do |f|
            f.file.each {|f| yield [@datastore.info.name,org,vdc,f.path]}
          end    
        end
      end
    end
  end

  class VCenter
    attr_reader :root,:scon

    def connect(host,user,pass=nil)
      pass ||= VCloud::SecurePass.new().decrypt(File.new('.vc','r').read)
      @name = host

      @vim = RbVmomi::VIM.
        connect({ :host => host, 
                  :user => user, 
                  :password => pass, 
                  :insecure => true,
                })
      @scon = @vim.serviceInstance.content
      @root = @scon.rootFolder
    end

    def vm(moref)
      @index_vm[moref.to_s] || Vm.new
    end

    def media(id)
      @index_media[id]
    end

    def load(dir)
      @dir = dir
      @doc = REXML::Document.
        new(File.new("#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml"))

      @index_vm = @doc.elements.inject("//HostSystem/VirtualMachine",{}) {|h,e|
        vm = Vm.new
        vm.load(e)
        h.update(e.attributes['moref'] => vm)
        h
      }
      @index_media = @doc.elements.inject("//MediaList/Media",{}) {|h,e|
        m = Media.new
        m.load(e)
        mpath = e.attributes['path']
        (mpath =~ /(\d+)\-media\.iso/ ||  # 1.0
         mpath =~ /media\-(.*)\.iso/) # 1.5
        h.update($1 => m)
        h
      }
    end

    def save(dir)
      xml = ERB.new(File.new("template/vcd-dump/#{self.class.name.sub(/VSphere::/,'')}.erb").read,0,'>').result(binding)
      FileUtils.mkdir_p(dir) unless File.exists? dir
      open("#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml",'w') {|f| f.puts xml}
    end
  end
end
