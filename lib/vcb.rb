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

module Chargeback

  class Task < XMLElement
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

  class VCB < XMLElement

    def connect(host,user,pass)
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
      RestClient.get(url) { |response, request, result, &block|
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
      RestClient.delete(url) { |response, request, result, &block|
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
