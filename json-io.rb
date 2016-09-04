#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require "awesome_print"

options = {}
OptionParser.new do |opts|
  opts.banner     = "json-io.rb: Ruby Json input output tool"
  opts.define_head  "Usage: whois.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " json-io.rb -j <json file> [--ap]"
  opts.separator    " json-io.rb -t <text line file>"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("-j", "--json [JSON FILE]", String, "import JSON filename") do |jsonfile|
    unless jsonfile then
      print("Error: -j, --json option, requires additional arguments.\n\n")
      exit 1
    end
    options[:jsonfile] = jsonfile
  end

  opts.on_tail("--ap", "Awesome Print Mode") do
    options[:ap] = true
  end

  opts.on("-t", "--text [TEXT FILE]", String, "import TEXT filename") do |textfile|
    unless textfile then
      print("Error: -text, --text option, requires additional arguments.\n\n")
      exit 1
    end
    options[:textfile] = textfile
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

if options[:textfile] then

  array = Array.new()

  File.read(options[:textfile]).each_line do |line|
    line.chop!
    next if line =~ /^$/
    next if line =~ /^#/
    array.push(line)
  end

  if array.length > 0 then
    puts JSON.pretty_generate(array)
  end

else

  File.open(options[:jsonfile]) do |file|
    hash = JSON.load(file)
    if options[:ap] then
      ap hash ,:indent => -2
    else
      pp hash
    end
  end

end
