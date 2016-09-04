#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require 'date'
require 'time'

ValidDNS = [ "nexia.jp", "awsdns" ]

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

    if hash["status"] == false then
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
        if Time.now > expires then
          error = true
          hash.store("error", "domain Expired.")
        end
      rescue => e
        error = true
        hash.store("error", "expires_on Time is Over.")
      end
    end

    if !error && !hash["nameservers"].nil? then
      dns_match = false
      ValidDNS.each do |dns|
        hit = hash["nameservers"].grep(Regexp.new(dns))
        dns_match = true if hit.length == 0
      end

      unless dns_match then
        error = true
        hash.store("error", "expires_on Time is Over.")
      end
    end

    # print("Error: ", hash["domain"], "\n") if error
    errDomain.push(hash) if error

  }
  return errDomain
end

File.open(options[:jsonfile]) do |file|
  arr = JSON.load(file)
  err = CheckStatus(arr)
  puts JSON.pretty_generate(err)
end
