#!/usr/bin/env ruby

require 'rubygems'
require 'optparse'
require 'json'
require 'pp'
require "awesome_print"

options = {}
OptionParser.new do |opts|
  opts.banner     = "json-edit.rb: Ruby Json edit tool"
  opts.define_head  "Usage: json-edit.rb [options]"
  opts.separator    ""
  opts.separator    "Examples:"
  opts.separator    " cat xxx.json | json-io.rb -j <json file> -o <object>"
  opts.separator    ""
  opts.separator    "Options:"

  opts.on("-j", "--json [JSON FILE]", String, "import JSON filename") do |jsonfile|
    unless jsonfile then
      print("Error: -j, --json option, requires additional arguments.\n\n")
      exit 1
    end
    options[:jsonfile] = jsonfile
  end

  opts.on_tail("-o", "--objname [object name]", String, "insert, modify object name") do |objname|
    unless objname then
      print("Error: -o, --objname option, requires additional arguments.\n\n")
      exit 1
    end
    options[:objname] = objname
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
if options[:jsonfile].nil? || options[:objname].nil? then
  print("Error: option not found\n\n")
  exit 1
end
str = ''
if File.pipe?(STDIN) || File.select([STDIN], [], [], 0) != nil then
  arr = []
  while line = $stdin.gets
    line.rstrip!
    next if line =~ /^$/
    next if line =~ /^#/
    arr << line
  end
  str = arr.join
else
  puts("STDIN input data is empty.")
  exit 1
end

# input edit data
hash =  JSON.load(str)
# puts JSON.pretty_generate(hash)

# save data file
json_data = open(options[:jsonfile]) do |io|
  JSON.load(io)
end
# puts JSON.pretty_generate(json_data)

json_data[options[:objname]] = hash

# 保存する
open(options[:jsonfile], "w") {|f| f.write JSON.pretty_generate(json_data)}
