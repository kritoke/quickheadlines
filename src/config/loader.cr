require "yaml"

def file_mtime(path : String) : Time
  File.info(path).modification_time
end

def load_config(path : String) : Config
  config = File.open(path) do |io|
    Config.from_yaml(io)
  end

  validate_config_feeds(config)

  config
end

def find_default_config : String?
  DEFAULT_CONFIG_CANDIDATES.find { |path| File.exists?(path) }
end

def parse_config_arg(args : Array(String)) : String?
  if arg = args.find(&.starts_with?("config="))
    return arg.split("=", 2)[1]
  end

  if args.size >= 1 && !args[0].includes?("=")
    return args[0]
  end

  nil
end

def load_validated_config(path : String) : ConfigLoadResult
  content = File.read(path)

  if content.starts_with?("\uFEFF")
    content = content[1..-1]
  end

  validate_yaml_structure(content)

  config = Config.from_yaml(content)

  validate_config_feeds(config)

  ConfigLoadResult.new(
    success: true,
    config: config,
    error_message: nil,
    error_line: nil,
    error_column: nil,
    suggestion: nil
  )
rescue ex : YAML::ParseException
  error_msg = ex.message || "Unknown YAML parsing error"

  error_line = nil
  error_column = nil

  if error_msg =~ /at line (\d+), column (\d+)/
    error_line = $1.to_i
    error_column = $2.to_i
  end

  suggestion = suggest_yaml_fix(error_msg, error_line)

  ConfigLoadResult.new(
    success: false,
    config: nil,
    error_message: error_msg,
    error_line: error_line,
    error_column: error_column,
    suggestion: suggestion
  )
rescue ex : File::Error
  ConfigLoadResult.new(
    success: false,
    config: nil,
    error_message: "Cannot read config file: #{ex.message}",
    error_line: nil,
    error_column: nil,
    suggestion: "Check file permissions and path"
  )
rescue ex
  ConfigLoadResult.new(
    success: false,
    config: nil,
    error_message: "Unexpected error: #{ex.message}",
    error_line: nil,
    error_column: nil,
    suggestion: "Check file format and encoding"
  )
end

private def validate_yaml_structure(content : String) : Nil
  lines = content.lines

  lines.each_with_index do |line, index|
    line_num = index + 1

    if line.includes?("\t")
      raise YAML::ParseException.new("Line #{line_num}: Contains tab character (use spaces instead)", line_num, 1)
    end

    if line.rstrip != line
      Log.for("quickheadlines.config").warn { "Line #{line_num}: Trailing whitespace detected" }
    end

    if line =~ /^(\s+)/
      indent = $1
      if indent.includes?("\t")
        raise YAML::ParseException.new("Line #{line_num}: Mixed tabs and spaces in indentation", line_num, 1)
      end
    end
  end

  non_empty_lines = lines.reject(&.strip.empty?)
  if lines.size > non_empty_lines.size
    trailing_blanks = lines.size - non_empty_lines.size
    Log.for("quickheadlines.config").warn { "Found #{trailing_blanks} trailing blank line(s) at end of file" }
  end
end

private def suggest_yaml_fix(error_msg : String, error_line : Int32?) : String?
  case error_msg
  when /cannot start any token/
    "Check for invalid characters, missing quotes, or incorrect indentation at line #{error_line}"
  when /mapping values are not allowed/
    "Check for missing colon or incorrect list syntax at line #{error_line}"
  when /did not find expected key/
    "Check for inconsistent indentation or missing key at line #{error_line}"
  when /unexpected character/
    "Check for special characters that need quotes at line #{error_line}"
  else
    "Check YAML syntax at line #{error_line}. Ensure proper indentation and no trailing spaces"
  end
end
