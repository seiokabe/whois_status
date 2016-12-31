#!/usr/bin/env ruby -n

# puts "hello: #{$_}" #prepend 'hello:' to each line from STDIN

### ruby -n
#these will all work:
# ./example.rb < input.txt
# cat input.txt | ./example.rb
# ./example.rb input.txt


if $stdin.tty?
  ARGV.each do |file|
    puts "do something with this file: #{file}"
  end
else
  $stdin.each_line do |line|
    puts "do something with this line: #{line}"
  end
end
