require 'rubygems'
require 'httparty'
require 'thread'

file_path = ARGV[0]
threads_per_user = ARGV[1]&.to_i || 6
users = ARGV[2]&.to_i || 1
tries = ARGV[3]&.to_i || 5

urls = File.read(file_path).split("\n").map(&:strip)
puts "With #{urls.size} URLS"
results = []

loop do
  # puts "Testing with #{users} users in #{threads_per_user} threads each"
  (0..users - 1).map do |user_num|
    downloaded = 0
    thread = Thread.new(urls.dup) do |user_urls|
      user_start = Time.now
      user_urls.each_slice((user_urls.size / threads_per_user.to_f).ceil).to_a.map do |group|
        Thread.new(group) do |user_urls|
          url = user_urls.shift
          while url
            uri = URI.parse(URI.encode(url))
            begin
              response = HTTParty.get(uri)
              unless response.code == 200
                puts "Not 200 for #{uri}"
                exit(-1)
              end
            rescue
              puts "Error #{$!} with #{uri}"
              exit(-1)
            end
            downloaded += 1
            url = user_urls.shift
          end
        end
      end.map(&:join)
      user_end = Time.now
      # puts "\t\tUser #{user_num} completed full page load with #{downloaded} URLs in #{user_end - user_start}s"
      results << user_end - user_start
    end
    thread
  end.map(&:join)
  tries -= 1
  if tries == 0
    average_time = results.reduce(:+) / results.size.to_f
    users_per_hour = 3600 / average_time * users
    puts "SERVING #{users_per_hour / 60.0} users per minute with #{users} simultaneous users"
    puts "SERVING #{users_per_hour} users per hour with #{users} simultaneous users"
    results = []
    puts "Completed with #{users}, incrementing"
    users += 1
    tries = ARGV[3]&.to_i || 5
  end
end
