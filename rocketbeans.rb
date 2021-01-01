#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'pry'

begin
  now = Time.now.to_i
  i = -1
  url = "https://api.rocketbeans.tv/v1/schedule/normalized?startDay=#{now-(i+1)*86400}&endDay=#{now-i*86400}"
  open(url) {|request|
    $schedule = JSON.parse(request.read, symbolize_names: true)
  }
rescue => e
  puts e.to_s
  exit 1
end

$schedule[:data].each {|day|
  puts Time.parse(day[:date]).localtime.to_date
  day[:elements].each {|entry|
    #next if entry[:type] == "rerun"
    type = entry[:type] ? "[#{entry[:type].upcase[0]}]" : ""
    color = "\033[1;30m"
    case entry[:type]
    when 'premiere'
      color = "\033[1;34m"
    when 'live'
      color = "\033[1;31m"
    end

    sub_title = entry[:topic]
    title = entry[:title]
    title = sub_title.to_s.empty? ? title : "#{title} - #{sub_title}"
    start_time = Time.parse(entry[:timeStart]).localtime.strftime("%H:%M")
    #if Time.parse(entry[:timeEnd]) >= Time.now
    puts "#{color}#{type}\t#{start_time}\t#{title} (#{entry[:duration]/60} Minuten)\t"
    #end
  }
}
