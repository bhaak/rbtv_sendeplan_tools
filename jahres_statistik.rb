#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'date'
require 'optparse'
require 'optparse/date'

def percentage a, b
  "#{1000*a/b/10.0}%"
end

def seconds_to_days seconds
  "#{10*seconds / 86400 / 10.0} Tage"
end

startDay = Date.new(2020, 1, 1).to_time.to_i
endDay   = Date.new(2021, 1, 1).to_time.to_i
cache = ".sendeplan_#{startDay}_#{endDay}.json"

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

# Cache die Sendeplan-Daten, die API ist ziemlich schnell, aber dann doch nicht
# so rasend schnell
if !File.exists?(cache)
  # https://github.com/rocketbeans/rbtv-apidoc
  url = "https://api.rocketbeans.tv/v1/schedule/normalized?startDay=#{startDay}&endDay=#{endDay}"
  URI.open(url) {|request|
    File.write(cache, request.read)
  }
end

json_data = File.read(cache)
@schedule = JSON.parse(json_data, symbolize_names: true)

shows = @schedule[:data].map {|a| a[:elements] }.flatten.reject {|s| s[:type] == 'rerun' }

# Datenbereinigungen
# 36 Sendungen haben keine Bohnen aufgelistet, aber bei einem Titel wie "Zocken
# mit Denzel" oder ein Topic wie "FTL mit Krogi" darf man davon ausgehen, dass
# die genannten Bohnen auch dabei waren.
bohnenlos = shows.select {|s| s[:bohnen].empty? }

denzel = bohnenlos.select {|s| s[:title].include? 'Zocken mit Denzel' }
denzel.each {|s| s[:bohnen] = [ {name: 'Dennis'} ] }

def add_bohne string, names, shows
  neue_bohnen = names.map {|name| { name: name } }
  shows.select {|s| s[:topic].end_with? string }.each {|s|
    s[:bohnen] = neue_bohnen
    s[:topic] = s[:topic][0..-(string.size+1)].strip
  }
end

add_bohne('mit Andreas', ['Andreas'], bohnenlos)
add_bohne('mit Budi', ['Budi'], bohnenlos)
add_bohne('mit Colin und Eddy', ['Colin', 'Etienne'], bohnenlos)
add_bohne('mit Eddy', ['Etienne'], bohnenlos)
add_bohne('mit Florentin', ['Florentin'], bohnenlos)
add_bohne('mit Florentin und Jannes', ['Florentin', 'Jannes'], bohnenlos)
add_bohne('mit Florentin, Jannes & Remo', ['Florentin', 'Jannes'], bohnenlos)
add_bohne('mit Krogi', ['Krogi'], bohnenlos)
add_bohne('mit Martin', ['Martin'], bohnenlos)
add_bohne('mit Nils', ['Nils'], bohnenlos)
add_bohne('mit Nils und Simon', ['Nils', 'Simon'], bohnenlos)
add_bohne('mit Sandro & RIME', ['Sandro'], bohnenlos)
add_bohne('mit Simon', ['Simon'], bohnenlos)
add_bohne('mit Simon & Budi', ['Simon', 'Budi'], bohnenlos)
add_bohne('mit Simon & Gregor', ['Simon', 'Gregor'], bohnenlos)
add_bohne('mit Simon - Total Tank Simulator', ['Simon', ], bohnenlos)
add_bohne('mit Simon und Budi', ['Simon', 'Budi'], bohnenlos)

def normalize_show show
  # Folgennummer aus Titel entfernen
  show[:title] = show[:title].gsub(/#?\d*$/, '').strip
  show
end

bohnenlos = shows.select {|s| s[:bohnen].empty? }
bohnen_shows = shows.reject {|s| s[:bohnen].empty? }
bohnen_shows.each {|s| normalize_show(s) }

total_bohnen_shows = bohnen_shows.map {|s| s[:duration] }.sum

puts "#{shows.count} Sendungen, davon"
puts "#{bohnen_shows.count} mit Bohnen (#{percentage(bohnen_shows.count, shows.count)}) und"
puts "#{bohnenlos.count} Sendungen als Drittcontent (#{percentage(bohnenlos.count, shows.count)}) ohne Bohnenbeteiligung."
puts
puts "Gesamthaft wurde letztes Jahr neuer Content für #{seconds_to_days(total_bohnen_shows)} am Stück gesendet."
puts
puts "Die folgenden Prozentzahlen sind immer relativ zu den Bohnen-Sendungen ohne Drittcontent."

# Bohne, Anzahl Sendungen
puts "\nDie 20 Bohnen mit den meisten Auftritten in Sendungen (Total #{bohnen_shows.count} Sendungen)"
bohnen = bohnen_shows.map {|s| s[:bohnen] }.flatten.map {|s| s[:name] }
bohnen.tally.sort_by{|_,v| -v }.take(20).each_with_index {|values, index|
  puts "#{index+1}. #{values[0]} (#{values[1]}, #{percentage(values[1], bohnen_shows.count)})"
}

# Bohne, Dauer der Sendung
puts "\nDie 20 Bohnen mit der längsten, aufsummierten Bildschirmzeit (Total #{seconds_to_days(total_bohnen_shows)})"
bohnen_dauer = Hash.new(0)
bohnen_shows.each {|s| s[:bohnen].each {|bohne| bohnen_dauer[bohne] += s[:duration] } }
bohnen_dauer.sort_by{|_,v| -v }.take(20).each_with_index {|values, index|
  puts "#{index+1}. #{values[0][:name]} (#{seconds_to_days(values[1])}, #{percentage(values[1], total_bohnen_shows)})"
}

# Shows, Anzahl
puts "\nDie 10 Shows, die am häufigsten gesendet wurden (Total #{bohnen_shows.count} Sendungen)"
bohnen_shows.map {|s| s[:title] }.tally.sort_by{|_,v| -v}.take(10).each_with_index {|values, index|
  puts "#{index+1}. #{values[0]} (#{values[1]} Folgen, #{percentage(values[1], bohnen_shows.count)})"
}

# Shows, Dauer der Sendung
shows_dauer = bohnen_shows.inject(Hash.new(0)) {|hash, s| hash[s[:title]] += s[:duration]; hash }
puts "\nDie 10 Shows mit der längsten, aufsummierten Sendedauer (Total #{seconds_to_days(shows_dauer.values.sum)})"
shows_dauer.sort_by{|_,v| -v }.take(10).each_with_index {|values, index|
  puts "#{index+1}. #{values[0]} (#{seconds_to_days(values[1])}, #{percentage(values[1], shows_dauer.values.sum)})"
}
