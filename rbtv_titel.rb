#!/usr/bin/env ruby

require 'open-uri'
require 'json'

begin
  now = Time.parse(ARGV[0]).to_i if ARGV[0]
  now ||= Time.now.to_i
  url = "https://api.rocketbeans.tv/v1/schedule/normalized?startDay=#{now}&endDay=#{now+86400}"
  URI.open(url) {|request|
    $schedule = JSON.parse(request.read, symbolize_names: true)
  }
rescue => e
  puts e.to_s
  exit 1
end

wochentage = [
  nil,
  "Montag",
  "Dienstag",
  "Mittwoch",
  "Donnerstag",
  "Freitag",
  "Samstag",
  "Sonntag",
]

$schedule[:data].each {|day|
  day[:elements].each {|entry|
    # Titel
    title = entry[:title].strip
    sub_title = entry[:topic].strip
    title = sub_title.to_s.empty? ? title : "#{title} - #{sub_title}"

    # Startzeit
    start_time = Time.parse(entry[:timeStart]).localtime
    live = entry[:type] == "live" ? "live " : ""
    time_formatted = "#{live}ab #{start_time.strftime("%H:%M")} Uhr"

    # Datum
    heute = start_time.to_date == Date.today ? "heute " : "am "
    wochentag = wochentage[start_time.wday]
    date_formatted = "#{heute}#{wochentag} (#{start_time.strftime("%2d.%m.%Y")})"

    # mit wem
    mit_bohnen = entry[:bohnen].empty? ? "" : " mit #{entry[:bohnen].map {|b| b[:name] }.join(" und ")}"

    puts "#{start_time.iso8601} #{title}, #{date_formatted} #{time_formatted}#{mit_bohnen} (#{entry[:duration]/60} Minuten)"
  }
}
