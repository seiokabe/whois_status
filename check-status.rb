#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require 'date'

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
today  = Date.today
puts today

def CheckStatus(arr)
  error = false
  errDomain = Array.new()
  arr.each{|hash|
    print hash["domain"]
    error = true unless hash[:status]
    error = true if hash[:available]
    # if hash[:expires_on]
    errDomain.push(hash) if error
    print(" : Error\n") if error
  }
  return errDomain
end

File.open(options[:jsonfile]) do |file|
  arr = JSON.load(file)
  err = CheckStatus(arr)
end
