#!/bin/env ruby

require 'optparse'
require 'date'
require 'rubygems'
require 'whois'

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
  #print("WhoisGet: #{domain}")
  hash = Hash.new()

  if domain.empty? then
     hash.store("status", false)
     hash.store("error", "domain is empty.")
     return _hash
  end

  domain.chop!
  ans = Wclient.lookup(domain)

  hash.store("domain", domain)

  available  = (ans.available?.nil?)  ? "N/A" : ans.available?
  registered = (ans.registered?.nil?) ? "N/A" : ans.registered?
  expires_on = (ans.expires_on.nil?)  ? "N/A" : "#{ans.expires_on.timezone('Asia/Tokyo')} (Origin: #{ans.expires_on})"
  registrar  = (ans.registrar.nil?)   ? "N/A" : ans.registrar.name
  created_on = (ans.created_on.nil?)  ? "N/A" : "#{ans.created_on.timezone('Asia/Tokyo')} (Origin: #{ans.created_on})"
  updated_on = (ans.updated_on.nil?)  ? "N/A" : "#{ans.updated_on.timezone('Asia/Tokyo')} (Origin: #{ans.updated_on})"

  hash.store("status", true)
  hash.store("available",  available)
  hash.store("registered", registered)
  hash.store("expires_on", expires_on)
  hash.store("registrar",  registrar)
  hash.store("created_on", created_on)
  hash.store("updated_on", updated_on)

  unless ans.nameservers.nil? then
    array = Array.new()
    i = 0
    ans.nameservers.each do |nameserver|
      #puts nameserver
      array[i] = nameserver.to_s
      i += 1
    end
    hash.store("nameservers", array)
  end

  return hash

end

params = {}
opt = OptionParser.new
opt.on('-d domain')   {|v| params[:d] = v }
opt.on('-f filename') {|v| params[:f] = v }
opt.on('-e') {|v| params[:e] = v }
opt.parse!(ARGV)

exit if params[:e]

if params[:d] then

  data = WhoisGet(params[:d])
  data.each{|key, value|
    print(key, ":\t", value, "\n")
  }
  print("\n")

else

  file = (params[:f].nil?) ? ".domain_list.txt" : "#{params[:f]}"

  File.read(file).each_line do |_domain|
    #print(_domain)
    data = WhoisGet(_domain)
    data.each{|key, value|
      print(key, ":\t", value, "\n")
    }
    print("\n")
  end

end
