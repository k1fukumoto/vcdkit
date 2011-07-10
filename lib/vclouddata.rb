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

  def init_attrs(node,attrs=[])
    ATTRS.each { |attr|
      s_attr = attr.to_s
      if (node.attributes[s_attr])
        eval "@#{s_attr} = node.attributes['#{s_attr}']"
      elsif (node.elements[s_attr])
        eval "@#{s_attr} = node.elements['#{s_attr}'].text"
      end
    }
  end

  def connect(vcd,node,attrs=[],method=:get,payload=nil,hdrs={})
    init_attrs(node,attrs)
    @vcd = vcd
    if(@href)
      case method
      when :get
        @xml = vcd.get(@href)
      when :post
        @xml = vcd.post(@href,payload,hdrs)
      when :put
        @xml = vcd.put(@href,payload,hdrs)
      end
      @doc = REXML::Document.new(@xml)
    end
    self
  end

  def load(dir)
    @dir = dir
    @doc = REXML::Document.
      new(File.new("#{dir}/#{self.class.name.sub(/VCloud::/,'')}.xml"))
    init_attrs(@doc.root)
    self
  end

  def save(dir)
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.class.name.sub(/VCloud::/,'')}.xml"
    open(path,'w') {|f| f.puts @xml}
  end

  def [](xpath)
    @doc.elements[xpath]
  end
  def elements
    @doc.elements
  end
  def match(xpath)
    REXML::XPath.match(@doc,xpath)
  end
  def alt
    REXML::Document.new(@vcd.get(@doc.elements["//Link[@rel='alternate']/@href"].value))
  end

  def compose_xml(node,hdr=true)
    return '' if node.nil?
    xml = ''
    if(hdr)
      node.attributes['xmlns'] = 'http://www.vmware.com/vcloud/v1'
      node.attributes['xmlns:ovf'] ='http://schemas.dmtf.org/ovf/envelope/1'
      xml = '<?xml version="1.0" encoding="UTF-8"?>'
    end
    REXML::Formatters::Default.new.write(node,xml)
    xml
  end
end

module VCloud
  class GuestCustomizationSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.guestCustomizationSection+xml'
    XML=<<EOS
<GuestCustomizationSection>
  <ChangeSid>true</ChangeSid>
  <JoinDomainEnabled>true</JoinDomainEnabled>
  <UseOrgSettings>false</UseOrgSettings>
  <DomainName><%= args['DomainName'] %></DomainName>
  <DomainUserName><%= args['DomainUserName'] %></DomainUserName>
  <DomainUserPassword><%= args['DomainUserPassword'] %></DomainUserPassword>
  <AdminPasswordEnabled>true</AdminPasswordEnabled>
  <AdminPasswordAuto>false</AdminPasswordAuto>
  <AdminPassword><%= args['AdminPassword'] %></AdminPassword>
  <ResetPasswordRequired>false</ResetPasswordRequired>
  <ComputerName><%= args['ComputerName'] %></ComputerName>
</GuestCustomizationSection>
EOS

    def compose(node,args)
      new = ERB.new(XML).result(binding)
      
      doc = REXML::Document.new(new)
      prev = nil
      doc.elements.each("/GuestCustomizationSection/*") do |e|
        n = node.elements[e.name]
        if n.nil?
          n = prev.next_sibling = REXML::Element.new(e.name)
        end
        n.text = e.text
        prev = n
      end
    end
  end

  class NetworkConnectionSection < XMLElement
    
    TYPE = 'application/vnd.vmware.vcloud.networkConnectionSection+xml'
  end

  class AccessSetting < XMLElement
  end

  class ControlAccessParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.controlAccess+xml'

    def each_access_setting
      @doc.elements.each("//AccessSetting"){|n| 
        as = AccessSetting.new
        as.connect(@vcd,n,[:type])
        yield as
      }
    end
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

  class DeployVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.deployVAppParams+xml'
    XML =<<EOS
<DeployVAppParams powerOn="true" xmlns="http://www.vmware.com/vcloud/v1"/>
EOS
    def initialize()
      @xml = ERB.new(XML).result(binding)
    end
  end

  class UndeployVAppParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.undeployVAppParams+xml'
    XML =<<EOS
<UndeployVAppParams saveState="false" xmlns="http://www.vmware.com/vcloud/v1"/>
EOS
    def initialize()
      @xml = ERB.new(XML).result(binding)
    end
  end

  class ComposeVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.composeVAppParams+xml'
    XML =<<EOS
<ComposeVAppParams name="<%= self.name %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<InstantiationParams>
  <%= self.compose_xml(ntwkcfg,false) %>
</InstantiationParams>
</ComposeVAppParams>

EOS
    def initialize(src,name)
      @name = name
      ntwkcfg = src.doc.elements['/VApp/NetworkConfigSection']
      ntwkcfg.elements.delete('//IpRange[not(node())]')

      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class InstantiateVAppTemplateParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.instantiateVAppTemplateParams+xml'
    XML =<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<InstantiateVAppTemplateParams 
  name="<%= dest %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
  <Description><%= desc %></Description> 

  <InstantiationParams>
    <NetworkConfigSection> 
      <ovf:Info/>
      <NetworkConfig networkName="<%= ntwk.name %>">
        <Configuration>
          <ParentNetwork href="<%= ntwk.href %>"/>
          <FenceMode>bridged</FenceMode>
        </Configuration>
      </NetworkConfig>
    </NetworkConfigSection>
  </InstantiationParams>

  <Source href="<%= src.entity_href %>"/>
</InstantiateVAppTemplateParams>
EOS
    def initialize(src,dest,ntwk,desc)
      @xml = ERB.new(XML).result(binding)
    end
  end
end
