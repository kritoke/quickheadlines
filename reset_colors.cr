#!/usr/bin/env crystal

require "./src/quickheadlines.cr"
require "./src/storage.cr"

include Quickheadlines

# Script to reset all header_text_color values in the database
# This forces re-extraction of theme-aware colors on next feed refresh

def main
  Quickheadlines::Storage.open do |db|
    puts "Resetting all header_text_color to force re-extraction..."
    
    begin
      db.exec("UPDATE feeds SET header_text_color = NULL")
      db.exec("UPDATE feeds SET header_theme_colors = NULL")
      puts "Reset complete! All feeds will re-extract colors on next refresh."
    rescue ex : SQLite3::Exception
      STDERR.puts "Error: #{ex.message}"
      exit 1
    end
  end
end

main
