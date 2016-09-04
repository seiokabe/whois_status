#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'date'
require 'whois'
require 'json'

defDomainListFile = "domain.txt"

array_domains = Array.new()

options = {}
OptionParser.new do |opts|
  opts.banner     = "whois.rb: an intelligent pure Ruby WHOIS Status Check client"
  opts.define_head  "Usage: whois.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " whois.rb -d example.jp -d example.com"
  opts.separator    " whois.rb -f <domain_list_filename> --text"
  opts.separator    ""
  opts.separator    " Defualt outpu json data"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("-d", "--domain [domain]", String, "target to domain name") do |domain|
    unless domain then
      print("Error: -d, --domain option, requires additional arguments.\n\n")
      exit 1
    end
    array_domains.push(domain)
  end

  opts.on("-f", "--file [FILE NAME]", String, "domain list filename (Default: #{defDomainListFile})") do |filename|
    options[:filename] = filename
  end

  options[:text] = false
  opts.on("-t", "--text", "Status Text View") do |text|
    options[:text] = text
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

Wclient = Whois::Client.new(:timeout => 5)

class Time
  def timezone(timezone = 'UTC')
    old = ENV['TZ']
    utc = self.dup.utc
    ENV['TZ'] = timezone
    output = utc.localtime
    ENV['TZ'] = old
    output
  end
end

def WhoisGet(domain)
  # print("WhoisGet: #{domain}", "\n")
  hash = Hash.new()

  if domain.empty? then
     hash.store("status", false)
     hash.store("error", "domain is empty.")
     return _hash
  end

  ans = Wclient.lookup(domain)

  hash.store("domain", domain)

  available  = (ans.available?.nil?)  ? "N/A" : ans.available?
  registered = (ans.registered?.nil?) ? "N/A" : ans.registered?
  # expires_on = (ans.expires_on.nil?)  ? "N/A" : "#{ans.expires_on.timezone('Asia/Tokyo')} (Origin: #{ans.expires_on})"
  expires_on = (ans.expires_on.nil?)  ? "N/A" : ans.expires_on.timezone('Asia/Tokyo')
  registrar  = (ans.registrar.nil?)   ? "N/A" : ans.registrar.name
  # created_on = (ans.created_on.nil?)  ? "N/A" : "#{ans.created_on.timezone('Asia/Tokyo')} (Origin: #{ans.created_on})"
  # updated_on = (ans.updated_on.nil?)  ? "N/A" : "#{ans.updated_on.timezone('Asia/Tokyo')} (Origin: #{ans.updated_on})"
  created_on = (ans.created_on.nil?)  ? "N/A" : ans.created_on.timezone('Asia/Tokyo')
  updated_on = (ans.updated_on.nil?)  ? "N/A" : ans.updated_on.timezone('Asia/Tokyo')

  hash.store("status", true)
  hash.store("available",  available)
  hash.store("registered", registered)
  hash.store("expires_on", expires_on)
  hash.store("registrar",  registrar)
  hash.store("created_on", created_on)
  hash.store("updated_on", updated_on)

  if !ans.nameservers.nil? && ans.nameservers.length > 0 then
    array = Array.new()
    ans.nameservers.each do |nameserver|
      array.push(nameserver.to_s)
    end
    hash.store("nameservers", array)
  end

  return hash
end

def PrintHash(hash)
  hash.each{|key, value|
    print(key, ":\t", value, "\n")
  }
  print("\n")
end

def whois_get(d)
  begin
    data = WhoisGet(d)
    return data
  rescue => e
    hash = Hash.new(d)
    hash.store("domain", d)
    hash.store("status", false)
    hash.store("error", e.message)
    return hash
  end
end

if array_domains.length == 0 then
  file = (options[:filename].nil?) ? defDomainListFile : "#{options[:filename]}"
  File.read(file).each_line do |domain|
    domain.chop!
    next if domain =~ /^$/
    next if domain =~ /^#/
    array_domains.push(domain)
  end
end

jsondata = Array.new()
jp_domain_count = 0
array_domains.each do |str_domain|

  if jp_domain_count > 10 then
    sleep(60)
    jp_domain_count = 0
  end
  jp_domain_count += 1

  data = whois_get(str_domain)
  if options[:text] then
    PrintHash(data)
  else
    jsondata.push(data)
  end
end

if jsondata.length > 0 then
  puts JSON.pretty_generate(jsondata)
end
