require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'date'

# Used to keep DRY values in mind
module FindAverage
  def find_average_value(hash, array)
    array.each do |number|
      hash[number] += 1
    end

    @max_frequency = hash.values.max
    @most_repeated_entries = hash.select { |_, frequency| frequency == @max_frequency }.keys
  end
end

# This class was used since we needed to store a variable without making it global
class HourManager
  attr_reader :most_repeated_entries, :frequency_hash, :total_hours

  include FindAverage

  def initialize
    @total_hours = []
    @frequency_hash = Hash.new(0)
  end

  def get_hour_values(hour)
    @total_hours.push(hour.split(' ')[1].split(':')[0].to_i)
  end

  def announce_average_hours
    puts "These are the hours of the day in which users registered the most: #{@most_repeated_entries}"
  end
end

# Added for the same reason as the above class
class DateManager
  attr_reader :most_repeated_entries, :frequency_hash, :total_register_dates

  include FindAverage

  def initialize
    @total_register_dates = []
    @frequency_hash = Hash.new(0)
  end

  def get_date_values(register_date)
    @total_register_dates.push(DateTime.strptime(register_date, '%m/%d/%y').to_date.strftime('%A'))
  end

  def announce_average_days
    puts "These are the days in which users registered the most: #{@most_repeated_entries}"
  end
end

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number.to_s.gsub(/\D/, '').sub(/^1/, '')
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

#################################################

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter
hour_manager = HourManager.new
date_manager = DateManager.new

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  hour_manager.get_hour_values(row[:regdate])
  date_manager.get_date_values(row[:regdate])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
end

hour_manager.find_average_value(hour_manager.frequency_hash, hour_manager.total_hours)
hour_manager.announce_average_hours
date_manager.find_average_value(date_manager.frequency_hash, date_manager.total_register_dates)
date_manager.announce_average_days
puts date_manager.frequency_hash
