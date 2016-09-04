#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require 'date'
require 'time'

validDNS = [ "nexia.jp", "awsdns" ]

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
now  = Time.now
puts now

def CheckStatus(arr)
  error = false
  errDomain = Array.new()
  arr.each{|hash|
    error = true unless hash["status"]
    error = true if hash["available"]

    if hash["expires_on"] == "N/A" then
      error = true
    else
      begin
        expires = Time.parse( hash["expires_on"] )
        error = true if Time.now > expires
      rescue => e
        error = true
      end
    end

    errDomain.push(hash) if error
  }
  return errDomain
end

File.open(options[:jsonfile]) do |file|
  arr = JSON.load(file)
  err = CheckStatus(arr)
  puts JSON.pretty_generate(err)
end
