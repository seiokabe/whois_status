#!/usr/bin/env ruby
# -*- coding:utf-8 -*-

require 'rubygems'
require 'optparse'
require 'net/http'
require 'uri'
require 'json'
require 'socket'
require 'openssl'
require 'timeout'
include OpenSSL

class GlobalSet
  def initialize()
    @checkBeforeDays = 30
    @timeout = 15
  end
  attr_accessor :checkBeforeDays
  attr_accessor :timeout
end

GS = GlobalSet.new()

array_hosts = Array.new()

options = {}
OptionParser.new do |opts|
  opts.banner     = "ssl-check-status.rb: an intelligent pure Ruby SSL expired status check"
  opts.define_head  "Usage: ssl-check.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " ssl-check-status.rb --url <URL> -v"
  opts.separator    " ssl-check-status.rb --host example.jp --host example.com:9443"
  opts.separator    " ssl-check-status.rb -f <SSL_URL_LIST_filename>"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("--host [host:<port>]", String, "target to host name. (Default: port 443)") do |host|
    unless host then
      print("Error: --host option, requires additional arguments.\n\n")
      exit 1
    end
    host = 'https://' + host unless host =~ /^https:\/\//
    array_hosts.push(host)
  end

  opts.on("--file [FILE NAME]", String, "SSL URL list filename") do |filename|
    unless filename then
      print("Error: --file option, requires additional arguments.\n\n")
      exit 1
    end
    options[:filename] = filename
  end

  opts.on("--url [url address]", String, "import JSON URL") do |url|
    unless url then
      print("Error: --url option, requires additional arguments.\n\n")
      exit 1
    end
    options[:url] = url
  end

  opts.on("--checkBeforeDays [int Days]", Integer, "check Before Expired Days. (Default: 0 [today])") do |days|
    unless days then
      GS.checkBeforeDays = 0
    else
      GS.checkBeforeDays = days
    end
  end

  opts.on("--timeout [int Sec]", Integer, "ssl test connection timeout option. (Default: 30)") do |t|
    unless t then
      GS.timeout = 15
    else
      GS.timeout = t
    end
  end

  options[:debug] = false
  opts.on("--debug", "run debug mode") do
    options[:debug] = true
  end

  options[:verbose] = false
  opts.on("-v", "--verbose", "Check SSL All Status View") do
    options[:verbose] = true
  end

  opts.on_tail("-h", "--help", "show this help and exit") do
    puts opts
    print("\n")
    exit
  end

  begin
    opts.parse!
  rescue OptionParser::ParseError
    # puts opts
    print("Error: OptionParser::ParseError\n\n")
    exit 1
  end
end

object = ARGV.shift

def getSSLstatus(url, options)

  uri = URI.parse(url)

  hash = Hash.new()
  hash.store("status", true)
  hash.store("url",  url)
  hash.store("host", uri.host)
  hash.store("port", uri.port)

  checkSecTime = GS.checkBeforeDays * 60 * 60 * 24

  # set SSL config
  ssl_context = SSL::SSLContext.new()
  ssl_context.ssl_version = :TLSv1
  # ssl_context.verify_mode=SSL::VERIFY_PEER

  # create ssl connection.
  begin
    Timeout.timeout(GS.timeout) {
      @soc = TCPSocket.new(uri.host.to_s, uri.port.to_i)
      @ssl = SSL::SSLSocket.new(@soc, ssl_context)
      @ssl.hostname = uri.host.to_s
      @ssl.connect
    }

  rescue Timeout::Error => e
    hash.store("status", false)
    hash.store("Error", "#{e.class} couldn't connext to #{uri.host.to_s}:#{uri.port.to_i}")
  rescue => e
    hash.store("status", false)
    hash.store("Error", "#{e.class} #{e.message}")
  end


  if hash["status"] then
    # check period.
    hash.store("subject", @ssl.peer_cert.subject.to_s)
    hash.store("expired", @ssl.peer_cert.not_after)
    hash.store("registered", @ssl.peer_cert.not_before)
    # p hash
    if (hash["expired"] - Time.now) < checkSecTime
      hash.store("status", false)
      hash.store("Error", "Certificate expired on #{hash['expired']}")
    end
  end

  @ssl.close
  @soc.close

  if options[:debug] then
    print("==== debug ====\n")
    puts JSON.pretty_generate(hash)
    print("===============\n")
  end

  if ( options[:verbose] == true || hash["status"] == false )
    return hash
  else
    return nil
  end

end

if array_hosts.length == 0 then

  if $stdin.tty?
    if options[:filename] then
      File.read(options[:filename]).each_line do |target|
        target.rstrip!
        next if target =~ /^$/
        next if target =~ /^#/
        target = 'https://' + target unless target =~ /^https:\/\//
        array_hosts.push(target)
      end
    elsif options[:url]
      if options[:url].match(/^https/).nil? then
        options[:url] = 'https://' + options[:url]
      end
      uri = URI.parse(options[:url])
      params = {'User-Agent' => "curl"}
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      res = https.start {
        https.get(uri.request_uri, params)
      }
      if res.code == '200'
        res.body.each_line do |target|
          target.rstrip!
          next if target =~ /^$/
          next if target =~ /^#/
          target = 'https://' + target unless target =~ /^https:\/\//
          array_hosts.push(target)
        end
      end
    end
  else
      while line = $stdin.gets
        line.rstrip!
        next if line =~ /^$/
        next if line =~ /^#/
        line = 'https://' + line unless line =~ /^https:\/\//
        array_hosts.push(line)
      end
  end

end

p array_hosts if options[:debug]

resArray = Array.new()
array_hosts.each do |url|
  data = getSSLstatus(url, options)
  # p data if options[:debug]
  resArray.push(data) unless data.nil?
end

if resArray.length > 0 then
  puts JSON.pretty_generate(resArray)
end
