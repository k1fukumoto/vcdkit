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
    $log.info("LOAD: #{self.path}/#{self.basename}")

    file = "#{dir}/#{self.path}/#{self.basename}"
    @dir = dir
    begin
      @doc = REXML::Document.new(File.new(file))
      init_attrs(@doc.root)
    rescue Exception => e
      $log.error("Failed to load xml file: #{file}: #{e}")
    end
    self
  end

  def basename()
    self.class.name.sub(/VCloud::/,'') + ".xml"
  end
  def paramsname()
    self.class.name.sub(/VCloud::/,'') + "Params.xml"
  end

  def save(dir)
    $log.info("SAVE: #{self.path}/#{self.basename}")

    dir = "#{dir}/#{self.path}"
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.basename}"
    open(path,'w') {|f| f.puts @xml}
  end

  def saveparam(dir)
    $log.info("SAVE: #{self.path}/#{self.paramsname}")

    dir = "#{dir}/#{self.path}"
    FileUtils.mkdir_p(dir) unless File.exists? dir
    path = "#{dir}/#{self.paramsname}"
    begin
      open(path,'w') do |f|
        erb = File.new("template/vcd-report/#{self.paramsname.sub('.xml','.erb')}").read
        xml = ERB.new(erb,0,'>').result(binding)
        doc = REXML::Document.new(xml)
        REXML::Formatters::Pretty.new.write(doc.root,f)
      end
    rescue Exception => e
      $log.warn("Failed to save parameters: #{path}: #{e}")
      raise e
    end
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

    def initialize(node)
      @node = node.elements['//GuestCustomizationSection']
      @node.elements.delete('./VirtualMachineId')
      @node.elements.delete('./Link')
      pass = @node.elements['./AdminPassword/text()']
      if(pass != '')
        @node.elements['./AdminPasswordAuto'].text = 'false'
      end
    end
    
    def extractParams
      @node.attributes.each {|name,value| @node.attributes.delete(name)}
      @node.elements.delete('./VirtualMachineId')
      @node.elements.delete('./Link')
      pass = @node.elements['./AdminPassword/text()']
      if(pass != '')
        @node.elements.delete('./AdminPasswordAuto')
      end
      self
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
    end

    def GuestCustomizationSection.compose(node,args)
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

    def initialize(node)
      @node = node.elements['//NetworkConnectionSection']
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
    end
  end

  class NetworkConfigSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.networkConfigSection+xml'

    def initialize(node)
      @node = node

      dhcp = @node.elements["//DhcpService[IsEnabled = 'false']"]
      if(dhcp)
        dhcp.elements.each('./*') do |n|
          next if n.name == 'IsEnabled'
          dhcp.delete(n)
        end
      end
    end

    def extractParams
      @node.elements.delete('.//VAppScopedVmId')
      self
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
    end
  end

  class StartupSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.startupSection+xml'
  end

  class LeaseSettingsSection < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.leaseSettingsSection+xml'

    def initialize(node)
      @node = node
    end

    def extractParams
      @node.name = 'Lease'
      @node.attributes.each {|name,value| @node.attributes.delete(name)}
      ['./ovf:Info','Link','StorageLeaseExpiration'].each {|n| @node.elements.delete(n)}
      self
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
    end
  end

  class AccessSetting < XMLElement
    def initialize(node)
      @node = node
    end

    def extractParams
      @node.elements['./Subject'].attributes.delete('type')
      self
    end

    def xml(hdr)
      self.compose_xml(@node,hdr)
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

  class EditVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.vApp+xml'
    XML =<<EOS
<VApp name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<Description><%= src['/VApp/Description/text()'] %></Description>
</VApp>
EOS
    def initialize(src)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class EditVmParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.vm+xml'
    XML =<<EOS
<Vm name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<Description><%= src['/Vm/Description/text()'] %></Description>
</Vm>
EOS
    def initialize(src)
      @xml = ERB.new(XML).result(binding)
      @doc = REXML::Document.new(@xml)
    end
  end

  class RecomposeVAppParams < XMLElement
    TYPE='application/vnd.vmware.vcloud.recomposeVAppParams+xml'
    XML =<<EOS
<RecomposeVAppParams name="<%= src.doc.root.attributes['name'] %>" 
  xmlns="http://www.vmware.com/vcloud/v1"
  xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1"> 
<InstantiationParams>
  <%= LeaseSettingsSection.new(src['/VApp/LeaseSettingsSection']).xml(false) %>
  <%= self.compose_xml(src['/VApp/ovf:StartupSection'],false) %>
  <%= NetworkConfigSection.new(src['/VApp/NetworkConfigSection']).xml(false) %>
</InstantiationParams>
</RecomposeVAppParams>

EOS
    def initialize(src)
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

  class Logger
    def initialize(logfile=nil)
      if(logfile)
        @logger = ::Logger.new(logfile,10,1024000)
      else
        @logger = ::Logger.new(STDOUT)
      end
      @logger.formatter = proc {|sev,time,prog,msg|
        ts = time.strftime('%Y-%m-%d %H:%M:%S')
        "#{ts} | #{sev} | #{msg}\n"
      }
    end

    def info(msg)
      @logger.info(msg)
    end
    def error(msg)
      @logger.error(msg)
    end
    def warn(msg)
      @logger.warn(msg)
    end
  end
end
