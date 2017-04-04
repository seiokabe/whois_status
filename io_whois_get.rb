#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# whois get for .io domain
# option
# #{__FILE__} domain_name ....

require 'net/http'
require 'rexml/document'
require 'time'
require 'json'
require 'nokogiri'


base_url = 'https://www.nic.io/go/whois/'

opts = []
ARGV.each do |v|
  opts = opts.push(v) if v =~ /\.io$/i
end

if opts.length < 1 then
  puts
  puts "Error: not xxx.io domain, or argv nothing."
  puts
  puts "#{__FILE__} domain_name ...."
  puts
  exit
end

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

data = []

opts.each do |opt|
  html = Net::HTTP.get(URI.parse(base_url + opt))

  charset = nil
  doc = Nokogiri::HTML.parse(html, nil, charset)

  table = doc.xpath('//td[@id="bodyfill"]/table')

  obj = {}
  obj["Domain"] = opt
  key = ''
  category = ''
  table.search('td').each do |node|
    text = node.text.gsub(/\n|\t/, '').strip

    category = node.text if node.attribute('colspan')

    if category == 'Domain Information' ||  category == 'Primary Nameserver' then

      if text =~ /:$/ then
        key = text.sub(/:$/, '').strip
      elsif !key.empty?
        if key == 'Name Server' then
          obj['Name Server'] = [] if obj['Name Server'].nil?
          obj['Name Server'].push(text)
        elsif key == 'Expiry'
          obj[key] = text.sub(/\.\.\..+$/, '').strip
        else
          obj[key] = text
        end
        key = ''
      end

    end
  end
  data.push(obj)
end

# puts JSON.pretty_generate(data) if data.length > 0

results = []
data.each do |item|
  obj = {}
  obj["domain"] = item["Domain"]
  if item["Domain Status"] == 'Live' then
    obj["status"]     = true
    obj["available"]  = false
    obj["registered"] = true
  else
    obj["status"]     = false
    obj["available"]  = true
    obj["registered"] = false
  end
  obj["expires_on"]  = Time.parse(item['Expiry'] + ' 00:00:00 +0900').timezone('Asia/Tokyo')
  obj["registrar"]   = 'N/A'
  obj["created_on"]  = Time.parse(item["First Registered"] + ' 00:00:00 +0900').timezone('Asia/Tokyo')
  obj["updated_on"]  = Time.parse(item["Last Updated"] + ' 00:00:00 +0900').timezone('Asia/Tokyo')
  obj["nameservers"] = item["Name Server"]
  results.push(obj)
end

puts JSON.pretty_generate(results) if results.length > 0

exit
