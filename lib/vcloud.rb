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
require 'rest_client'
require 'rexml/document'
require 'erb'
require 'pp'

class XMLElement
  ATTRS = [:name, :href]
  attr_accessor(*ATTRS)
  attr_reader :xml, :doc

  def initialize(vcd,node,attrs=[])
    ATTRS.each { |attr|
      s_attr = attr.to_s
      if (node.attributes[s_attr])
        eval "@#{s_attr} = node.attributes['#{s_attr}']"
      elsif (node.elements[s_attr])
        eval "@#{s_attr} = node.elements['#{s_attr}'].text"
      end
    }

    @vcd = vcd
    if(@href)
      @xml = vcd.get(@href)
      @doc = REXML::Document.new(@xml)
    end
  end

  def save(dir)
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.class.name}.xml"
    open(path,'w') {|f| f.puts @xml}
  end
end

module VCloud
  class Vm < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'
  end

  class ControlAccessParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.controlAccess+xml'
  end

  class CloneVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.cloneVAppParams+xml'
    XML =<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<CloneVAppParams name="<%= name %>" xmlns="http://www.vmware.com/vcloud/v1">
  <Description><%= desc %></Description> 
  <Source href="<%= src %>"/>
</CloneVAppParams>
EOS

    def initialize(src,name,desc)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class VApp < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vApp+xml'

    def initialize(vcd,node)
      super(vcd,node)
      n = REXML::XPath.first(@doc, "/VApp/Link[@type='#{ControlAccessParams::TYPE}' and @rel='down']")
      @cap = ControlAccessParams.new(vcd,n)
    end

    def vm(name)
      Vm.new(@vcd,@doc.elements["//Children/Vm[@name='#{name}'"])
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| yield Vm.new(@vcd,n)}
    end

    def save(dir)
      super
      self.each_vm {|vm| vm.save("#{dir}/VM/#{vm.name}")}
      @cap.save(dir)
    end
  end

  class Vdc < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vdc+xml'

    def initialize(vcd,node)
      super(vcd,node)
    end

    def vapp(name)
      VApp.new(@vcd,@doc.elements["//ResourceEntity[@type='#{VApp::TYPE}' and @name='#{name}']"])
    end

    def each_vapp
      @doc.elements.each("//ResourceEntity[@type='#{VApp::TYPE}']"){|n| yield VApp.new(@vcd,n)}
    end

    def save(dir)
      super
      self.each_vapp {|vapp| vapp.save("#{dir}/VAPP/#{vapp.name}")}
    end

    def cloneVApp(src,name,desc='')
      href = REXML::XPath.first(@doc, "//Link[@type='#{CloneVAppParams::TYPE}' and @rel='add']").attributes['href']
      xml = CloneVAppParams.new(src.href,name,desc).xml
      resp = @vcd.post(href, xml , :content_type => CloneVAppParams::TYPE)
    end
  end

  class Org < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.org+xml'

    def initialize(vcd,node)
      super(vcd,node)
    end

    def vdc(name) 
      Vdc.new(@vcd,@doc.elements["//Link[@type='#{Vdc::TYPE}' and @name='#{name}']"])
    end

    def each_vdc
      @doc.elements.each("//Link[@type='#{Vdc::TYPE}']") {|n| yield Vdc.new(@vcd,n)}
    end

    def save(dir)
      super
      self.each_vdc {|vdc| vdc.save("#{dir}/VDC/#{vdc.name}")}
    end
  end

  class VCD 
    def initialize(host,org,user,pass)
      resp = RestClient::Resource.new("https://#{host}/api/v1.0/login",
                                      :user => "#{user}@#{org}",
                                      :password => pass).post(nil)
      @auth_token = {:x_vcloud_authorization => resp.headers[:x_vcloud_authorization]}
      @xml = resp.to_s
      @doc = REXML::Document.new(@xml)
    end

    def org(name)
      Org.new(self,@doc.elements["//OrgList/Org[@name='#{name}']"])
    end

    def each_org
      @doc.elements.each("//OrgList/Org") {|n| yield Org.new(self,n)}
    end

    def get(url)
      return RestClient.get(url,@auth_token)
    end

    def post(url,payload,hdrs)
      return RestClient.post(url,payload,hdrs.update(@auth_token))
    end

    def save(dir)
      self.each_org {|org| org.save("#{dir}/ORG/#{org.name}")}
    end
  end
end




