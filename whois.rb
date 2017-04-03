#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'date'
require 'whois'
require 'json'

defDomainListFile = "domain.txt"
error_wait_time   = 3 # if error whois_get then retry loop, sleep sec.
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
    options[:domain] = true
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

def testWhois(debug)
  array = ["google.com", "docker.io", "google.co.jp", "softbank.jp"]
  array.each{|d|
    puts("domain: #{d}") if debug
    begin
      data = WhoisGet(d)
      puts JSON.pretty_generate(data) if debug
    rescue => e
      puts e if debug
    end
  }
end

def WhoisGet(domain)
  # print("WhoisGet: #{domain}", "\n")
  hash = Hash.new()

  if domain.empty? then
     hash.store("status", false)
     hash.store("error", "domain is empty.")
     return _hash
  end

  wclient = Whois::Client.new(:timeout => 30)

  ans = wclient.lookup(domain)

  hash.store("domain", domain)

  available  = (ans.available?.nil?)  ? "N/A" : ans.available?
  registered = (ans.registered?.nil?) ? "N/A" : ans.registered?
  # expires_on = (ans.expires_on.nil?)  ? "N/A" : "#{ans.expires_on.timezone('Asia/Tokyo')} (Origin: #{ans.expires_on})"
  expires_on = (ans.expires_on.nil?)  ? "0" : ans.expires_on.timezone('Asia/Tokyo')
  registrar  = (ans.registrar.nil?)   ? "N/A" : ans.registrar.name
  # created_on = (ans.created_on.nil?)  ? "N/A" : "#{ans.created_on.timezone('Asia/Tokyo')} (Origin: #{ans.created_on})"
  # updated_on = (ans.updated_on.nil?)  ? "N/A" : "#{ans.updated_on.timezone('Asia/Tokyo')} (Origin: #{ans.updated_on})"
  created_on = (ans.created_on.nil?)  ? "N/A" : ans.created_on.timezone('Asia/Tokyo')
  updated_on = (ans.updated_on.nil?)  ? "N/A" : ans.updated_on.timezone('Asia/Tokyo')

  hash.store("status", false)
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
    data.store("status", true)
    return data
  rescue => e
    data = Hash.new()
    data.store("domain", d)
    data.store("status", false)
    data.store("expires_on", "0")
    data.store("error", e.message)
    return data
  end
end


if array_domains.length == 0 then
  if $stdin.tty?
    file = (options[:filename].nil?) ? defDomainListFile : "#{options[:filename]}"
    File.read(file).each_line do |domain|
      # domain.chop!
      domain.rstrip!
      next if domain =~ /^$/
      next if domain =~ /^#/
      array_domains.push(domain)
    end
  else
    while line = $stdin.gets
      line.rstrip!
      next if line =~ /^$/
      next if line =~ /^#/
      array_domains.push(line)
    end
  end

  ## test whois  args true is 'debug print'
  testWhois(false) if options[:domain].nil?
end

jsondata = Array.new()
threads  = Array.new()

locks = Queue.new
2.times { locks.push :lock }

array_domains.each do |str_domain|
  threads << Thread.new {
    lock = locks.pop
    for i in 1..3 do
      # puts("whois_get: #{str_domain}")
      data = whois_get(str_domain)
      break if data["error"].nil?
      data["error"] += ", loop: #{i}"
      sleep(error_wait_time)
    end

    jsondata.push(data)
    locks.push lock
  }
end
threads.each { |t| t.join }

if jsondata.length > 0 then
  if options[:text] then
    jsondata.each { |data| PrintHash(data) }
  else
    puts JSON.pretty_generate(jsondata)
  end
end
