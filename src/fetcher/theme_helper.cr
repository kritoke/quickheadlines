require "json"

module Fetcher
  module ThemeHelper
    private def extract_theme_text(parsed_text : JSON::Any, current_text : String?) : String?
      return current_text unless current_text.nil? || current_text == ""

      new_text = parsed_text.is_a?(Hash) ? (parsed_text["light"]? || parsed_text["dark"]?) : parsed_text
      new_text.to_s if new_text
    rescue ex
      Log.for("quickheadlines.feed").error(exception: ex) { "extract_theme_text" }
      nil
    end

    private def parse_legacy_theme(header_color : String?, header_text_color : String?, header_theme_json : String?) : {String?, String?}
      return {header_color, header_text_color} unless header_theme_json

      final_header_color = header_color
      final_header_text = header_text_color

      begin
        parsed = JSON.parse(header_theme_json).as_h

        if (parsed_text = parsed["text"]?) && (new_text = extract_theme_text(parsed_text, final_header_text))
          final_header_text = new_text
        end

        if (parsed_bg = parsed["bg"]?) && (final_header_color.nil? || final_header_color == "")
          final_header_color = parsed_bg.to_s
        end
      rescue ex
        Log.for("quickheadlines.feed").error(exception: ex) { "parse_legacy_theme(parse)" }
      end

      {final_header_color, final_header_text}
    end

    private def parse_theme_text_value(text_val) : Hash(String, String)?
      return unless text_val

      has_text = (text_val.is_a?(Hash) && !text_val.empty?) || (text_val.is_a?(String) && !text_val.empty?)
      return unless has_text

      if text_val.is_a?(Hash)
        result = {} of String => String
        text_val.each { |k, v| result[k.to_s] = v.to_s }
        result
      else
        ColorExtractor.normalize_text_value(text_val.to_s)
      end
    end

    private def normalize_bg_value(extracted : Hash?) : String?
      return unless extracted && extracted.has_key?("bg")

      raw_bg = extracted["bg"]
      if raw_bg.is_a?(String)
        raw_bg
      elsif raw_bg.is_a?(JSON::Any)
        begin
          raw_bg.as_s
        rescue TypeCastError
          raw_bg.to_s
        end
      else
        raw_bg.to_s
      end
    end

    private def extract_header_colors(feed : Feed, favicon_path : String?) : {String?, String?, String?}
      if favicon_path && favicon_path.starts_with?("/favicons/")
        begin
          extracted = ColorExtractor.extract_theme_colors(favicon_path, feed.url, feed.header_color)

          if extracted && extracted.is_a?(Hash) && extracted.has_key?("text")
            text_val = extracted["text"]

            parsed_text = parse_theme_text_value(text_val)

            if parsed_text
              theme_payload = {
                "bg"     => (extracted.has_key?("bg") ? extracted["bg"] : nil),
                "text"   => parsed_text || {"light" => nil, "dark" => nil},
                "source" => "auto",
              }

              header_theme_json = theme_payload.to_json

              legacy_text = parsed_text["light"]? || parsed_text["dark"]?

              bg_val = normalize_bg_value(extracted)

              return {bg_val, legacy_text, header_theme_json}
            end
          end
        rescue ex
          Log.for("quickheadlines.feed").error(exception: ex) { "extract_header_colors(theme-aware)" }
        end
      end

      {feed.header_color, feed.header_text_color, nil}
    end
  end
end
