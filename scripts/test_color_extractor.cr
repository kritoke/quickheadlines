# Quick script to exercise ColorExtractor helpers
require "../src/color_extractor"

puts "Testing ColorExtractor luminance and contrast"

bg = [240, 240, 240]
puts "bg=#{bg} -> (contrast vs black) #{ColorExtractor.contrast([0,0,0], bg).round(2)}"

dark = ColorExtractor.find_dark_text_for_bg_public(bg)
light = ColorExtractor.find_light_text_for_bg_public(bg)

puts "Selected dark text for light bg: #{dark}"
puts "Selected light text for light bg: #{light}"

bg2 = [20, 20, 20]
puts "bg2=#{bg2} -> (contrast vs white) #{ColorExtractor.contrast([255,255,255], bg2).round(2)}"
puts "Selected dark text for dark bg: #{ColorExtractor.find_dark_text_for_bg_public(bg2)}"
puts "Selected light text for dark bg: #{ColorExtractor.find_light_text_for_bg_public(bg2)}"
