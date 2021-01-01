#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'date'
require 'optparse'
require 'optparse/date'

startDay = (Date.today-7).to_time.to_i
endDay   = (Date.today+1).to_time.to_i

OptionParser.new do |opts|
  opts.banner = "bohnen.rb [Optionen] BOHNEN\n"+
    " Liefert alle Shows, in der eine bestimmte Bohne innerhalb eines\n"+
    " bestimmten Zeitraums aufgetreten ist.\n"+
    " Default-Zeitraum umfasst die letzten 7 Tage.\n\n"

  opts.on("-h", "--help", "Dieser Hilfetext") do
    puts opts
    exit
  end

  opts.on("-b", "--beginn [DATUM]", Date, "Erster Tag des Abfrage-Zeitraums") do |date|
    startDay = date.to_time.to_i
  end
  opts.on("-e", "--ende [DATUM]", Date, "Letzter Tag des Abfrage-Zeitraums") do |date|
    endDay = date.to_time.to_i
  end
end.parse!

bohnen = ARGV.map(&:strip).map(&:downcase)

raise 'Gib mindestens eine Bohne an' if bohnen.empty?

url = "https://api.rocketbeans.tv/v1/schedule/normalized?startDay=#{startDay}&endDay=#{endDay}"
URI.open(url) {|request|
  @schedule = JSON.parse(request.read, symbolize_names: true)
  shows = @schedule[:data].map {|a| a[:elements] }.flatten.reject {|s| s[:type] == 'rerun' }
  filtered = shows.select {|s| s[:bohnen].any? {|b| bohnen.include? b[:name].downcase } }
  filtered.each {|s|
    puts "#{s[:timeStart][0..9]} #{[s[:title].strip, s[:topic].strip].reject(&:empty?).join(' - ')}"
  }
}
