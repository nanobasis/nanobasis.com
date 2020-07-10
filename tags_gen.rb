#!/usr/bin/env ruby

# generates tag pages for each tag used within _posts
# use --future to create tag pages for future posts

# License: MIT
# Copyright: 2018 Taylor Brink <taylor@nanobasis.com>

require 'time'

if ARGV.length < 4
  print "\nUsage: ruby tags_gen.rb [OPTIONS] SRC_DIR TAGS_DIR LAYOUT URL_PATH\n\nOPTIONS\n" +
    "  --future\n    create tags when date in future\n\n" +
    "EXAMPLE\n  ruby tags_gen.rb --future _posts _tags/tags tagpage /tags\n" +
    "  ruby tags_gen.rb _projects _tags/projects projectstags /projects/tags\n\n"
  exit 1
end

url_path = ARGV.pop
layout = ARGV.pop

tags_dir = ARGV.pop
if !Dir.exists?(tags_dir)
  print "TAGS_DIR: '#{tags_dir}' does not exist\n"
  exit 1
end

posts_dir = ARGV.pop
if !Dir.exists?(posts_dir)
  print "SRC_DIR: '#{posts_dir}' does not exist\n"
  exit 1
end

print "generating tags ... "

tags = []

# collect tags into array
Dir.glob(posts_dir + "/*.md") do |filename|
  File.open(filename, "r") do |f|

    publish = true
    cur_tags = []

    f.each_with_index do |line, i|
      next if i == 0

      if line.length > 5
        # do not publish future posts
        if line[0..5] == "date: "
          publish = false if Time.parse(line[6..-1].strip) > Time.now
        end

        # split tags on space
        if line[0..5] == "tags: "
          cur_tags = line[6..-1].strip.split(' ')
          next
        end

        # support collection tags
        if line[0..5] == "tags2:"
          cur_tags = line[6..-1].strip.split(' ')
          next
        end
      end

      if line.strip == "---" && cur_tags.size > 0
        # only publish current (unless --future arg provided)
        if publish || ARGV.include?("--future")
          tags = (tags + cur_tags).uniq
        end
        break
      end
    end
  end
end

# remove old OR create directory
Dir.glob(tags_dir + "/*.md") { |f| File.delete(f) }
Dir.mkdir(tags_dir) if !Dir.exist?(tags_dir)

# write tags page with template
tags.each do |tag|
  File.open(File.join(tags_dir, "#{tag}.md"), "w") do |f|     
    f.write("---\nlayout: #{layout}\npermalink: #{url_path}/#{tag}\n" +
      "title: \"Tag: #{tag}\"\ntag: #{tag}\nrobots: noindex\n---\n")   
  end
end

print "#{tags.size} tags added.\n"
