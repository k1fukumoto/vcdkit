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

module VCloud

  class LoginParam < XMLElement
    XML=<<EOS
<?xml version="1.0" encoding="UTF-8"?>
<Request xmlns="http://www.vmware.com/vcenter/chargeback/1.5.0">
<Request>
  <Users>
    <User>
      <Type>local</Type>
      <Name>${user}</Name>
      <Password>${pass}</Password>
    </User>
  </Users>
</Request>
EOS
    def initialize(user,pass)
      @xml = ERB.new(XML).result(binding)
    end
  end

  class VCB < XMLElement

    def connect(host,user,pass)
      url = "https://#{host}/vCenter-CB/api/login"
      self.post(url,LoginParam.new(user,pass).xml)
      self
    end

    def get(url)
      $log.info("HTTP GET: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.get(url,@auth_token) { |response, request, result, &block|
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
      $log.info("HTTP DELETE: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.delete(url,@auth_token) { |response, request, result, &block|
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
      $log.info("HTTP POST: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.post(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
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
      $log.info("HTTP PUT: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.put(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
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
