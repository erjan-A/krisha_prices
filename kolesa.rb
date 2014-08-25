require 'mechanize'
require 'rubygems'

url = "http://kolesa.kz/cars/toyota/land-cruiser-200/?auto-car-grbody=2&year%5Bfrom%5D=2012&year%5Bto%5D=2012"

avg_prices = (1..4).map do |page|
	url = "#{url}&page=#{page}"

	agent = Mechanize.new
	page = agent.get(url).parser 

	prices = page.css(".header-search span.price").text.split("$").map{|e| e.gsub(/[^0-9]/i, '').to_i}
	
	sorted = prices.sort
	2.times {sorted.pop; sorted.shift}

	(sorted.inject(0, &:+))/sorted.size
end

puts (avg_prices.inject(0, &:+))/avg_prices.size

