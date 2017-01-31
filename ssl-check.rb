#!/usr/bin/env ruby
# -*- coding:utf-8 -*-

require 'rubygems'
require 'optparse'
require 'uri'
require 'json'
require 'socket'
require 'openssl'
require 'timeout'
include OpenSSL

defUrlListFile = "ssl.txt"

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
  opts.banner     = "ssl-check.rb: an intelligent pure Ruby SSL expired status check"
  opts.define_head  "Usage: ssl-check.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " ssl-check.rb --host example.jp --host example.com:9443"
  opts.separator    " ssl-check.rb -f <SSL_URL_LIST_filename>"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("--host [host:<port>]", String, "target to host name. (Default: port 443)") do |host|
    unless host then
      print("Error: --host option, requires additional arguments.\n\n")
      exit 1
    end
    array_hosts.push('https://' + host)
  end

  opts.on("--file [FILE NAME]", String, "SSL URL list filename (Default: #{defUrlListFile})") do |filename|
    options[:filename] = filename
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
  ssl_conf = SSL::SSLContext.new()
  # ssl_conf.verify_mode=SSL::VERIFY_PEER

  # create ssl connection.
  begin
    Timeout.timeout(GS.timeout) {
      @soc = TCPSocket.new(uri.host.to_s, uri.port.to_i)
      @ssl = SSL::SSLSocket.new(@soc, ssl_conf)
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
    file = (options[:filename].nil?) ? defUrlListFile : "#{options[:filename]}"
    File.read(file).each_line do |target|
      target.rstrip!
      next if target =~ /^$/
      next if target =~ /^#/
      target = 'https://' + target if target =~ /^https:¥/¥//
      array_hosts.push(target)
    end
  else
      while line = $stdin.gets
        line.rstrip!
        next if line =~ /^$/
        next if line =~ /^#/
        array_hosts.push(line)
      end
  end

end

resArray = Array.new()
array_hosts.each do |url|
  data = getSSLstatus(url, options)
  # p data if options[:debug]
  resArray.push(data) unless data.nil?
end

if resArray.length > 0 then
  puts JSON.pretty_generate(resArray)
end
