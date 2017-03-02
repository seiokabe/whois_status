#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require 'date'
require 'time'
require 'net/http'
require 'uri'

ValidDNS = [ "nexia.jp", "awsdns-", 'ns1.xserver.jp' ]

class CheckDns
  def initialize()
    @flag = false
    @beforeDays = 0
  end
  attr_accessor :flag
  attr_accessor :beforeDays
end

CD = CheckDns.new()

options = {}
OptionParser.new do |opts|
  opts.banner     = "check-status.rb: whois status check."
  opts.define_head  "Usage: check-status.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " check-status.rb -j <json file>"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("-j", "--json [JSON FILE]", String, "import JSON filename") do |jsonfile|
    unless jsonfile then
      print("Error: -j, --json option, requires additional arguments.\n\n")
      exit 1
    end
    options[:jsonfile] = jsonfile
  end

  opts.on("-u", "--url [url address]", String, "import JSON URL") do |url|
    unless url then
      print("Error: -u, --url option, requires additional arguments.\n\n")
      exit 1
    end
    options[:url] = url
  end

  opts.on("--checkDns","nameserver checking option") do
    CD.flag = true
  end

  opts.on("--checkBeforeDays [Int Days]", Integer, "check Before Expired Days") do |days|
    unless days then
      CD.beforeDays = -1
    else
      CD.beforeDays = days
    end
  end

  opts.on_tail("-h", "--help", "show this help and exit") do
    puts opts
    print("\n")
    exit
  end

  begin
    opts.parse!
  rescue OptionParser::ParseError
    print("Error: OptionParser::ParseError\n\n")
    exit 1
  end
end

object = ARGV.shift

def CheckStatus(arr)
  errDomain = Array.new()
  arr.each{|hash|
    error = false
    # pp hash

    if hash["status"].nil? == true then
      error = true
      hash.store("error", "whois json data. status nil.")
    elsif hash["status"] == false then
      error = true
    elsif hash["available"] == true then
      error = true
      hash.store("error", "available is true.")
    elsif hash["expires_on"] == "N/A" then
      error = true
      hash.store("error", "expires_on is Empty.")
    else
      begin
        expires = Time.parse(hash["expires_on"])
        time = Time.now + ( CD.beforeDays * 60 * 60 * 24 )
        if time > expires then
          error = true
          hash.store("error", "domain Expired.")
        end
      rescue => e
        error = true
        hash.store("error", "expires_on Time is Over.")
      end
    end

    if ( CD.flag && error == false && hash["nameservers"].nil? == false ) then
      # print("====== ", hash["domain"], "\n")
      dns_match = false
      ValidDNS.each do |dns|
        # puts dns
        # puts hash["nameservers"]
        hit = hash["nameservers"].grep(Regexp.new(dns))
        if hit.length > 0 then
          dns_match = true
          break
        end
      end

      unless dns_match then
        error = true
        hash.store("error", "nameservers is not found.")
      end
    end

    # print("Error: ", hash["domain"], "\n") if error
    errDomain.push(hash) if error

  }
  return errDomain
end

if $stdin.tty?
  if options[:jsonfile] then
    File.open(options[:jsonfile]) do |file|
      arr = JSON.load(file)
      err = CheckStatus(arr)
      puts JSON.pretty_generate(err) if err.length > 0
    end
    exit 0
  elsif options[:url] then
    uri = URI.parse(options[:url])
    params = {'User-Agent' => "curl"}
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    res = https.start {
      https.get(uri.request_uri, params)
    }
    if res.code == '200'
      arr = JSON.parse(res.body)
      err = CheckStatus(arr)
      puts JSON.pretty_generate(err) if err.length > 0
      exit 0
    else
      puts "Error: #{res.code} #{res.message}"
      exit 1
    end
  end
else
  lines = ""
  while str = $stdin.gets
    lines << str
  end
  arr = JSON.load(lines)
  err = CheckStatus(arr)
  puts JSON.pretty_generate(err) if err.length > 0
  exit 0
end

print("\n Error: NotFound whois Json data.\n\n")
print(" show help\n")
print("           check-status.rb --help\n\n")
