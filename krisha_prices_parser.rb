require 'mechanize'
require 'rubygems'
require 'nokogiri'

ENTRIES_PER_PAGE = 20.0
CURRENCY_BASE_URL = "http://www.nationalbank.kz/"

def parse_prices(values={})

	# urls
	base_url = "http://krisha.kz/#{values[:type]}/#{values[:property_type]}/#{values[:city]}"
	base_url1 = values[:district].nil? ?  "#{base_url}/?" : "#{base_url}-#{values[:district]}/?"
	home_base_url = values[:complex_value].nil? ? base_url1 : "#{base_url1}das[map.complex]=#{values[:complex_value]}&"

	puts home_base_url
	# Mechanize
	agent = Mechanize.new
	page = agent.get(home_base_url).parser 

	# Total entries
	total_entries = page.css("span.active small.smaller").text.gsub(/[^0-9]/i, '').to_i

	# Total pages = total entries / entries per page
	total_pages = (total_entries/ENTRIES_PER_PAGE).ceil	

	# Total price for 1 sq. m.
	total_avg_price_entries = get_avg(total_pages, home_base_url, values[:property_type])
	total_avg_price = total_avg_price_entries[:price]


	return {:total_entries => total_avg_price_entries[:total_entries_parsed], :avg_price => total_avg_price, :avg_price_usd => kzt_convert(total_avg_price, 'usd'), :avg_price_eur => kzt_convert(total_avg_price, 'eur')}
end


def get_avg(total_pages, home_base_url, property_type)
	pages_parsed = 0
	total_entries_parsed = 0

	# Iterate over pages
	s = (1..[total_pages, 50].min).map do |p|
		retries = 2

		begin
			url = "#{home_base_url}page=#{p}"
			agent = Mechanize.new
			page = agent.get(url).parser

			avgp_e = get_avg_prices_entries(page, property_type)
			avg_price = avgp_e[:price]
		rescue StandardError => e
			puts "Error: #{e}"
			# if retries > 0
			# 	puts "\tTrying #{retries} more time(s)"
			# 	retries -= 1
			# 	sleep 1
			# 	retry
			# else
			# 	puts "Can't parse data from page #{p}, moving on"
			# end
		else
			# puts "\tGot page #{p}"
			pages_parsed += 1
			total_entries_parsed += avgp_e[:total_entries]
			avg_price unless avg_price.nil?
		ensure
			# sleep 1
		end


	end # END pages loop

	return {:price => (s.flatten.compact.inject(0, &:+)/[pages_parsed, 1].max).round, :total_entries_parsed => total_entries_parsed}

end


# Average prices per sm per 1 apartment;  > 50000 to exclude small values (arenda)
def get_avg_prices_entries(page, property_type)
	entries_parsed = 0

	avg_prices = get_prices_from_page(page, property_type).compact.map do |p, sm| 
		begin 
			p/sm
		rescue StandardError => e
			warn "HERE"
		end
	end

	# Average price per sm of all apartments per page and total entries
	price = avg_prices.compact.inject{ |sum, el| sum + el }.to_f / avg_prices.size
	entries_parsed += avg_prices.compact.count	

	{:price => price, :total_entries => entries_parsed}
end


# iterate over every entry on page
def get_prices_from_page(page, type)	
	(0...(page.css(".title a").count)).map do |n| 
		sm = if ['kvartiry', 'doma', 'dachi'].include?(type)
			page.css("div.descr span.cross")[n].text.split('м2')[0].gsub(/[^0-9.]/i, '').to_f
		else
			page.css(".title a")[n].text.split('м2')[0].gsub(/[^0-9.]/i, '').to_f
		end
		prices = page.css("span.price span.curs_kzt")[n].text.split('.')[0].gsub(/[^0-9a-z ]/i, '').to_f
		[prices, sm] if prices != 0 and !prices.nil? and sm != 0 and !sm.nil?
	end
end


# Converts to $, €: rates of National Bank of KZ
def kzt_convert amount, to_currency
	agent = Mechanize.new
	page = agent.get(CURRENCY_BASE_URL).parser

	case to_currency
	when 'usd'
		(amount/(page.css("td.gen14_1 table")[0]).css('tr td')[1].text.to_f).round
	when 'eur'
		(amount/(page.css("td.gen14_1 table")[1]).css('tr td')[1].text.to_f).round
	else
		"Wrong currency. Only usd and eur is allowed."
	end
end


# Variables
type = "arenda"
property_type = "kvartiry"
city = "astana"
district = nil # "esilskij" "almatinskij", "saryarkinskij"
complex_value = 267


# Output
output = parse_prices(
	:city => city,
	:type => type,
	:property_type =>property_type,
	:district => district,
	:complex_value => complex_value
	)

text = "Из #{output[:total_entries]} объявлении средняя цена за 1 кв. м. – #{city} "
t_pt = " #{type} #{property_type}:"

puts complex_value.nil?

output_text = if district
	(text + "#{district}" + t_pt)
elsif complex_value
	(text + "#{complex_value}" + t_pt) 
else
	text + t_pt
end

puts output_text
puts "\t#{output[:avg_price]} Тг.\n\t#{output[:avg_price_usd]} $\n\t#{output[:avg_price_eur]} €"



