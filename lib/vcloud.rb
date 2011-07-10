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
      puts "*** COMPOSE-1"
      puts new
      
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

  class Task < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.task+xml'
    def status
      if (@doc.nil? || @doc.elements["//Task/@status"].nil?)
        "success"
      else
        @doc.elements["//Task/@status"].value
      end
    end
  end

  VAPPSTATUS = {
    "4" => "Powered On",
    "8" => "Powered Off",
  }

  class Vm < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'
  
    def saveparam(dir)
      FileUtils.mkdir_p(dir) unless File.exists? dir

      open("#{dir}/VMParams.xml",'w') do |f|
        xml = ERB.new(File.new("template/vcd-report/VMParams.erb").read,0,'>').result(binding)
        doc = REXML::Document.new(xml)
        REXML::Formatters::Pretty.new.write(doc.root,f)
      end
    end

    def os
      @doc.elements["//ovf:OperatingSystemSection/ovf:Description/text()"]
    end

    def status
      VAPPSTATUS[@doc.elements["/Vm/@status"].value] || "Busy"
    end

    def thumbnail
      @vcd.get(@doc.elements["//Link[@rel='screen:thumbnail']/@href"].value).body
    end

    def moref
      @doc.elements["//VCloudExtension/vmext:VimObjectRef/vmext:MoRef/text()"]
    end
    
    def powerOff
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//Link[@rel='power:powerOff']"],
                   [], :post)
    end

    def connectNetwork(nic,name,mode)
      ncon = @doc.elements["//NetworkConnection[NetworkConnectionIndex ='#{nic}']"]
      ncon.attributes['network'] = name
      ncon.elements["//IsConnected"].text = 'true'
      ncon.elements["//IpAddressAllocationMode"].text = mode
      cfg = ncon.elements["../"]

      task = Task.new
      task.connect(@vcd,
                   cfg.elements["//Link[@type='#{NetworkConnectionSection::TYPE}']"],
                   [], :put,
                   self.compose_xml(cfg),
                   :content_type => NetworkConnectionSection::TYPE)
    end

    def customize(args)
      cfg = @doc.elements["//GuestCustomizationSection"]
      GuestCustomizationSection.new.compose(cfg,args)

      task = Task.new
      task.connect(@vcd,
                   cfg.elements["//Link[@type='#{GuestCustomizationSection::TYPE}']"],
                   [], :put,
                   self.compose_xml(cfg),
                   :content_type => GuestCustomizationSection::TYPE)
    end
  end

  class VApp < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vApp+xml'
    attr_reader :cap

    def connect(vcd,node)
      super(vcd,node)
      n = REXML::XPath.first(@doc, "/VApp/Link[@type='#{ControlAccessParams::TYPE}' and @rel='down']")
      @cap = ControlAccessParams.new
      @cap.connect(vcd,n)
      self
    end

    def saveparam(dir)
      FileUtils.mkdir_p(dir) unless File.exists? dir

      open("#{dir}/VAppParams.xml",'w') do |f|
        xml = ERB.new(File.new("template/vcd-report/VAppParams.erb").read,0,'>').result(binding)
        doc = REXML::Document.new(xml)
        REXML::Formatters::Pretty.new.write(doc.root,f)
      end
      self.each_vm {|vm| vm.saveparam("#{dir}/VM/#{vm.name}")}
    end

    def vm(name)
      vm = Vm.new
      vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
    end

    def status
      VAPPSTATUS[@doc.elements["/VApp/@status"].value] || "Busy"
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = Vm.new
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load("#{@dir}/VM/#{n.attributes['name']}")
        end
        yield vm
      }
    end

    def deploy()
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//Link[@type='#{DeployVAppParams::TYPE}']"],
                   [], :post,
                   DeployVAppParams.new().xml,
                   {:content_type => DeployVAppParams::TYPE})
    end

    def save(dir)
      super
      self.each_vm {|vm| vm.save("#{dir}/VM/#{vm.name}")}
      @cap.save(dir)
    end

    def load(dir)
      super
      @cap = ControlAccessParams.new
      @cap.load(dir)
      self
    end

    def powerOn
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "4")
        task.connect(@vcd,
                     @doc.elements["/VApp/Link[@rel='power:powerOn']"],
                     [], :post)
      end
      task
    end

    def powerOff
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "8")
        task.connect(@vcd,
                     @doc.elements["/VApp/Link[@rel='power:powerOff']"],
                     [], :post)
      end
      task
    end
    
    def undeploy
      task = Task.new
      if(@doc.elements["VApp/@deployed"].value == "true")
        task.connect(@vcd,
                     @doc.elements["//Link[@type='#{UndeployVAppParams::TYPE}']"],
                     [], :post,
                     UndeployVAppParams.new().xml,
                     {:content_type => UndeployVAppParams::TYPE})
      end
      task
    end

    def delete
      @vcd.delete(@doc.elements["/VApp/Link[@rel='remove']/@href"].value)
    end
  end

  class Vdc < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vdc+xml'

    def vapp(name)
      vapp = VApp.new
      vapp.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VApp::TYPE}' and @name='#{name}']"])
    end

    def each_vapp
      @doc.elements.each("//ResourceEntity[@type='#{VApp::TYPE}']"){|n|
        vapp = VApp.new
        if(@vcd)
          vapp.connect(@vcd,n)
        elsif(@dir)
          vapp.load("#{@dir}/VAPP/#{n.attributes['name']}")
        end
        yield vapp
      }
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

    def deployVApp(ci,name,ntwk,desc='')
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//Link[@type='#{InstantiateVAppTemplateParams::TYPE}' and @rel='add']"],
                   [], :post,
                   InstantiateVAppTemplateParams.new(ci,name,ntwk,desc).xml,
                   {:content_type => InstantiateVAppTemplateParams::TYPE})
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

  class CatalogItem < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalogItem+xml'

    def entity_href
      @doc.elements["/CatalogItem/Entity/@href"].value
    end
  end

  class Catalog < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalog+xml'

    def catalogitem(name)
      ci = CatalogItem.new
      ci.connect(@vcd,@doc.elements["//CatalogItem[@name='#{name}']"])
    end

    def each_catalogitem
      @doc.elements.each("//CatalogItem") do |n|
        ci = CatalogItem.new
        if(@vcd)
          ci.connect(@vcd,n)
        elsif(@dir)
          ci.load("#{@dir}/CATALOGITEM/#{n.attributes['name']}")
        end
        yield ci
      end
    end

    def save(dir)
      super
      self.each_catalogitem {|ci| ci.save("#{dir}/CATALOGITEM/#{ci.name}")}
    end
  end

  class OrgNetwork < XMLElement
    TYPE='application/vnd.vmware.vcloud.network+xml'
  end

  class Org < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.org+xml'

    def vdc(name) 
      vdc = Vdc.new
      vdc.connect(@vcd,@doc.elements["//Vdcs/Vdc[ @name='#{name}']"])
    end

    def each_vdc
      @doc.elements.each("//Vdcs/Vdc") {|n| 
        vdc = Vdc.new
        if(@vcd)
          vdc.connect(@vcd,n)
        elsif(@dir)
          vdc.load("#{@dir}/VDC/#{n.attributes['name']}")
        end
        yield vdc
      }
    end

    USERPATH ='//Users/UserReference'

    def user(name)
      user = User.new
      user.connect(self,@doc.elements["#{USERPATH}[@name='#{name}']"])
    end

    def each_user
      @doc.elements.each(USERPATH) { |n| 
        user = User.new
        if(@vcd)
          user.connect(@vcd,n)
        elsif(@dir)
          user.load("#{@dir}/USER/#{n.attributes['name']}")
        end
        yield user
      }
    end

    def network(name)
      ntwk = OrgNetwork.new
      ntwk.connect(@vcd,@doc.elements["//Networks/Network[@name='#{name}']"])
    end

    CATPATH = '//Catalogs/CatalogReference'

    def catalog(name)
      cat = Catalog.new
      cat.connect(@vcd,@doc.elements["#{CATPATH}[@name='#{name}']"])
    end

    def each_catalog
      @doc.elements.each(CATPATH) {|n| 
        cat = Catalog.new
        if(@vcd)
          cat.connect(@vcd,n)
        elsif(@dir)
          cat.load("#{@dir}/CATALOG/#{n.attributes['name']}")
        end
        yield cat
      }
    end

    def save(dir)
      super
      self.each_vdc {|vdc| vdc.save("#{dir}/VDC/#{vdc.name}")}
      self.each_catalog {|cat| cat.save("#{dir}/CATALOG/#{cat.name}")}
      self.each_user {|user| user.save("#{dir}/USER/#{user.name}")}
    end
  end

  class User < XMLElement
  end

  class VCD < XMLElement
    def connect(host,org,user,pass)
      resp = RestClient::Resource.new("https://#{host}/api/v1.0/login",
                                      :user => "#{user}@#{org}",
                                      :password => pass).post(nil)
      @auth_token = {:x_vcloud_authorization => resp.headers[:x_vcloud_authorization]}

      @xml = self.get("https://#{host}/api/v1.0/admin")
      @doc = REXML::Document.new(@xml)
    end

    def load(dir,*target)
      case target.size
      when 0
        super
        @auth_token = nil
      when 3
        org = target[0]
        vdc = target[1]
        vapp = target[2]
        VApp.new.load("#{dir}/ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}")
      end
    end

    def save(dir,*target)
      case target.size
      when 0
        super
        self.each_org {|org| org.save("#{dir}/ORG/#{org.name}")}
      when 3
        org = target[0]
        vdc = target[1]
        vapp = target[2]
        self.org(org).vdc(vdc).vapp(vapp).save("#{dir}/ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}")
      end
    end

    ORGPATH='//OrganizationReferences/OrganizationReference'

    def org(name)
      org = Org.new
      org.connect(self,@doc.elements["#{ORGPATH}[@name='#{name}']"])
    end

    def each_org
      @doc.elements.each(ORGPATH) { |n| 
        org = Org.new
        if(@auth_token)
          org.connect(self,n)
        elsif(@dir)
          org.load("#{@dir}/ORG/#{n.attributes['name']}")
        end
        yield org
      }
    end

    def get(url)
      return RestClient.get(url,@auth_token)
    end

    def delete(url)
      return RestClient.delete(url,@auth_token)
    end

    def post(url,payload=nil,hdrs={})
      RestClient.post(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        if ENV['RESTCLIENT_LOG']
          puts "*** request"
          puts payload
          puts "*** response"
          puts response
        end
        response.return!(request,result,&block)
      }
    end

    def put(url,payload=nil,hdrs={})
      RestClient.put(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        if ENV['RESTCLIENT_LOG']
          puts "*** request"
          puts payload
          puts "*** response"
          puts response
        end
        response.return!(request,result,&block)
      }
    end

    def wait(task)
      while task.status == 'running'
        sleep(3)
        node = task.doc.root
        task = Task.new
        task.connect(self,node)
      end
    end
  
  end
end
