require "http/client"

def detect_github_repo : String?
  begin
    process = Process.new("git", ["remote", "get-url", "origin"],
      output: Process::Redirect::Pipe,
      error: Process::Redirect::Pipe)

    url = process.output.gets_to_end.strip

    if process.wait.success?
      if url =~ %r{github.com[/:]([^/]+)/([^/.]+?)(\.git)?$}
        owner = $1
        repo = $2
        return "#{owner}/#{repo}"
      end
    end
  rescue
  end

  nil
end

def fetch_config_from_github(repo_path : String, branch : String = "main") : String?
  unless repo_path =~ /\A[a-zA-Z0-9_-]+\/[a-zA-Z0-9_-]+\z/
    STDERR.puts "[WARN] Invalid repo_path format (must be owner/repo): #{repo_path}"
    return
  end

  url = "https://raw.githubusercontent.com/#{repo_path}/#{branch}/feeds.yml"

  begin
    response = HTTP::Client.get(url)
    if response.status_code == 200
      return response.body
    elsif response.status_code == 404 && branch == "main"
      return fetch_config_from_github(repo_path, "master")
    end
  rescue ex
    STDERR.puts "Error fetching config from GitHub: #{ex.message}"
  end

  nil
end

def download_config_from_github(target_path : String) : Bool
  if repo_path = detect_github_repo
    if yaml_content = fetch_config_from_github(repo_path)
      begin
        Config.from_yaml(yaml_content)

        File.write(target_path, yaml_content)
        STDERR.puts "[#{Time.local}] Auto-downloaded feeds.yml from GitHub (#{repo_path})"
        return true
      rescue ex : YAML::ParseException
        STDERR.puts "Error: Invalid YAML in downloaded feeds.yml: #{ex.message}"
      rescue ex : File::Error
        STDERR.puts "Error: Cannot write feeds.yml to #{target_path}: #{ex.message}"
      rescue ex
        STDERR.puts "Error: Failed to save feeds.yml: #{ex.message}"
      end
    else
      STDERR.puts "Error: Could not fetch feeds.yml from GitHub (file may not exist in repository)"
    end
  else
    STDERR.puts "Error: Could not detect GitHub repository (not in a git repo or no origin remote)"
  end

  false
end
