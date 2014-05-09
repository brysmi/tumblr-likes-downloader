require 'tumblr_client'
require 'mechanize'
require 'date'
require 'yaml'
require 'uri'

require 'pry'
require 'pry-nav'
binding.pry

THREADPOOL_SIZE = 2
SEGMENT_SIZE = 25

HISTORY_FILE = File.join(File.dirname(__FILE__), "previous.yml")

previous_dled_ids = YAML.load(File.open(HISTORY_FILE)) rescue []

directory = "tumblr-likes"

require_relative 'creds'

likes = client.likes
liked_count = likes["liked_count"]

puts "I like #{liked_count}"

likes = []

# restrict liked count so we are only getting a small manageable amount for testing

liked_count = 50

puts "Now I like #{liked_count}"

(0...liked_count).each do |i|
  if i==0 or i%SEGMENT_SIZE==0
     p "getting #{SEGMENT_SIZE} more likes starting at #{i}: #{likes.count} thus far"
     client.likes({:limit => SEGMENT_SIZE, :offset => i})["liked_posts"].each do |like|
	puts "#{like['post_url']}"
	p "This one was a #{like['type']}" if like['type'] != 'photo'
        likes << like if like["type"] == 'photo' and !previous_dled_ids.include?(like["id"])
     end
  end

end


if likes.empty? 
  p "no new likes!"
  exit 0
end 

puts "#{likes.count} new likes!"

# some of this code comes from https://github.com/jamiew/tumblr-photo-downloader

already_had = 0

threads = []

# work out the slices of likes based on likes.count / 4, so each slice would be 
# roughly 1100 likes in each group
likes.each_slice(likes.count / THREADPOOL_SIZE ).each do |group|

#  threads << Thread.new {
#    begin
##      p "launching thread #{threads.size + 1}"
#      p "launching thread #{threads.size}"

# i think it is launching more than one thread which is looking at the same pool, hence 
# why some fetches are duplicated early on
# it outputs:
# launching thread 2
# launching thread 2
# launching thread 5
# launching thread 5
# when it should be 2 3 4 5, they are separate threads, but the numbers refer to which 
# block of likes it's going to fetch

      group.each do |like|

        i = 0
        like["photos"].each do |photo|					# for each pic in like
          url = photo["original_size"]["url"]

          filename = "#{like["blog_name"]}-#{like["slug"]}-"
          filename += "#{i}-" if i > 0					# append i for when there are multiple pics per like
          filename += File.basename(URI.parse(url).path.split('?')[0])
#         if File.exists?("#{directory}/#{filename}")
          if File.exist?("#{directory}/#{filename}")
            puts "Already have #{url}"
            already_had += 1				# not used except by my addition
          else
            begin
              puts "Saving photo #{url}"
              file = Mechanize.new.get(url)
              file.save_as("#{directory}/#{filename}")
            rescue Mechanize::ResponseCodeError => e
              puts "Error #{e.response_code} getting file for #{url}"
            end
          end
          i += 1
          previous_dled_ids << like['id']            
        end
      end
#    rescue Exception => e
#      puts "unhandled exception:, #{$!}"
#    end
#    p "closing thread"
#  }
  
end

# threads.each{|t| t.join }     # wait till all the threads finish

YAML.dump(previous_dled_ids, File.open(HISTORY_FILE, "w"))

puts "Already had #{already_had} pics"
