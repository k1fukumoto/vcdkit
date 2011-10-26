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
require 'oci8'
require 'pp'

module Chargeback

  class Task < XMLElement
	XML=<<EOS
  <QueuedTasks>
    <QueuedTask id="433" type="EXPORT_REPORT">
      <Status>QUEUED</Status>
      <Progress>0.0</Progress>
      <CreatedOn>1311302010358</CreatedOn>
      <CreatedBy>1</CreatedBy>
      <CreatedByName>vcdadmin</CreatedByName>
      <ModifiedOn>1311302010358</ModifiedOn>
      <ModifiedBy />
      <Result>
        <Report id="10670">
          <Hierarchy id="">
            <Name />
          </Hierarchy>
        </Report>
      </Result>
    </QueuedTask>
  </QueuedTasks>
</Response>
EOS
    def status
    end
  end

# <Request xmlns="http://www.vmware.com/vcenter/chargeback/1.5.0">
  class LoginParam < XMLElement
    XML=<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<Request>
  <Users>
    <User>
      <Type>local</Type>
      <Name><%= user %></Name>
      <Password><%= pass %></Password>
    </User>
  </Users>
</Request>
EOS
    def initialize(user,pass)
      @xml = ERB.new(XML).result(binding)
    end
  end


  class SearchReportParam < XMLElement
    XML=<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<Request>
<SearchQueries>
  <SearchQuery id="report">
    <Criteria type="AND">
      <Filter name="name" type="LIKE" value="<%= name %>" /> 
    </Criteria>
    <Pagination>
      <FirstResultCount>0</FirstResultCount>
      <MaxResultCount>100</MaxResultCount>
    </Pagination> 
  </SearchQuery>
</SearchQueries>
</Request>
EOS
    def initialize(name)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class VCBDB
    attr_reader :conn   

    class DCThread
      attr_reader :name,:lastProcessTime
      INIT =<<EOS
SELECT server_property_value
FROM cb_server_property
WHERE server_property_name like '<%= name %>'
EOS
      def initialize(conn,name)
        sql = ERB.new(INIT).result(binding)
        conn.exec(sql) do |r|
          @lastProcessTime = Time.at(Integer(r[0])/1000)
        end
      end
    end

    class VM
      SEARCH_BY_STARTTIME <<EOS
SELECT che.cb_hierarchical_entity_id heid,
       ch.hierarchy_name org, 
       ce2.entity_name vapp,
       che.entity_display_name vm, 
       chr.start_time created, 
       chr.end_time deleted
FROM cb_hierarchy_relation chr 
  INNER JOIN cb_hierarchical_entity che 
    ON chr.entity_id = che.cb_hierarchical_entity_id
  INNER JOIN cb_entity ce 
    ON che.entity_id = ce.entity_id
  INNER JOIN cb_hierarchy ch
    ON che.hierarchy_id = ch.hierarchy_id
  INNER JOIN cb_hierarchical_entity che2
    ON chr.parent_entity_id = che2.cb_hierarchical_entity_id
  INNER JOIN cb_entity ce2
    ON che2.entity_id = ce2.entity_id
WHERE chr.start_time > to_date('20111018', 'yyyymmdd') 
  AND end_time is not null
  AND ce.entity_type_id = 0
ORDER BY ch.hierarchy_name, chr.start_time
EOS
      def VM.searchByStartTime(opts)
        sql = ERB.new(SEARCH_BY_STARTTIME).result(binding)
        conn.exec(sql) do |r|
          pp r
        end
      end
    end

    def connect(host,dbname)
      pass = VCloud::SecurePass.new().decrypt(File.new('.vcbdb','r').read)
      c = 0
      while @conn.nil? && c<5
        begin 
          $log.info("Connecting VCB database #{host}/#{dbname}")
          @conn = OCI8.new('vcb',pass,"//#{host}/#{dbname}")
        rescue Exception => e
          $log.info("#{e}")
          sleep(3)
          c += 1
        end
      end
      @conn
    end

    def dcThreads
      ['vmijob.lastProcessTime',
       'cbEventListRawView.lastProcessTime',
       'vcLastProcessTime-%'].collect do |name|
        DCThread.new(@conn,name)
      end
    end
  end

  class VCB < XMLElement
    def connect(host,user)
      pass = VCloud::SecurePass.new().decrypt(File.new('.vcb','r').read)
      @url = "https://#{host}/vCenter-CB/api"
      resp = self.post("#{@url}/login",LoginParam.new(user,pass).xml)
      @cookies = resp.cookies 
      self
    end

    def searchReport(name)
      resp = self.post("#{@url}/search",SearchReportParam.new(name).xml)
      @xml = resp.body
      @doc = REXML::Document.new(@xml)
      @doc.elements.collect("//Report") {|r| r.attributes['id']}
    end

    def exportReport(id)
      resp = self.get("#{@url}/report/#{id}/export?exportFormat=XML")
      @xml = resp.body
      puts @xml
      @doc = REXML::Document.new(@xml)
    end

    def get(url)
      $log.info("HTTP GET: #{url}")
      hdrs = {:cookies => @cookies} if @cookies
      RestClient.get(url,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def delete(url)
      $log.info("HTTP DELETE: #{url}")
      hdrs = {:cookies => @cookies} if @cookies
      RestClient.delete(url,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def post(url,payload=nil,hdrs={})
      $log.info("HTTP POST: #{url}")
      hdrs.update(:cookies => @cookies) if @cookies
      RestClient.post(url,payload,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def put(url,payload=nil,hdrs={})
      $log.info("HTTP PUT: #{url}")
      hdrs.update(:cookies => @cookies) if @cookies
      RestClient.put(url,payload,hdrs) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
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
