#!/usr/bin/ruby

TS = '[\d\-]+ [\d:]+'

ARGV.each do |file|
  f = File.new(file)
  while(line = f.gets)
    next unless line =~ /^(#{TS}) .* Last Fixed Cost (#{TS})\((\d+) secs old\)/
    puts "#{$1},#{$3},#{$2}"
  end
end
