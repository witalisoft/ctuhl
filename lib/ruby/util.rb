def has_snippet_start_marker(line)
    line.valid_encoding? && line.match?(/[^\/]snippet:(\S*)/)
  end
  
  def has_file_start_marker(line)
    line.valid_encoding? && line.match?(/<!-- file:(\S*) -->/)
  end
  
  def is_empty(line)
    line.valid_encoding? && line.gsub(/\s+/, "").size == 0
  end
  
  def has_indention(line)
    line.valid_encoding? && !is_empty(line) && line.match?(/^(\s)/)
  end
  
  def get_indention(line)
    if match = line.match(/^(\s)/)
      match.captures[0]
    end
  end
  
  def has_file_end_marker(line)
    line.valid_encoding? && line.match?(/<!-- \/file:(\S*) -->/)
  end
  
  def has_snippet_end_marker(line)
    line.valid_encoding? && line.match?(/\/snippet:(\S*)/)
  end
  
  def extract_file_id(line)
    if match = line.match(/file:(\S*)/)
      match.captures[0]
    end
  end
  
  def extract_snippet_id(line)
    if match = line.match(/\/?snippet:(\S*)/)
      match.captures[0]
    end
  end
  
  def create_lines(file)
    lines = []
    line_number = 1
  
    lines = File.readlines(file).map do |line|
      line_info = {}
      line_info[:content] = line
      line_info[:empty] = is_empty(line)
  
      if (has_snippet_start_marker(line))
        line_info[:snippet_start] = true
        line_info[:snippet_id] = extract_snippet_id(line)
      elsif (has_snippet_end_marker(line))
        line_info[:snippet_end] = true
        line_info[:snippet_id] = extract_snippet_id(line)
      elsif (has_file_start_marker(line))
        line_info[:file_start] = true
        line_info[:file_id] = extract_file_id(line)
      elsif (has_file_end_marker(line))
        line_info[:file_end] = true
        line_info[:file_id] = extract_file_id(line)
      else
        line_info[:number] = line_number
        line_number += 1
      end
  
      if has_indention(line)
        line_info[:indented] = true
        line_info[:indention] = get_indention(line)
      else
        line_info[:indented] = false
      end
  
      line_info
    end
  
    lines
  end
  
  def extract_snippets(lines)
    snippets = {}
  
    lines.each_with_index do |line_info,index|
      if (line_info[:snippet_start])
        snippet = {}
        snippet[:start] = index
        snippets[line_info[:snippet_id]] = snippet
      end
  
      if (line_info[:snippet_end])
        if !snippets[line_info[:snippet_id]]
          puts "no snippet start found for '#{line_info[:snippet_id]}'"
        end
  
        snippets[line_info[:snippet_id]][:end] = index
      end
    end
  
    snippets
  end
  
  def extract_files(lines)
    files = {}
  
    lines.each_with_index do |line_info,index|
      if (line_info[:file_start])
        file = {}
        file[:start] = index
        files[line_info[:file_id]] = file
      end
  
      if (line_info[:file_end])
        if !files[line_info[:file_id]]
          puts "no file start found for '#{line_info[:file_id]}'"
        end
  
        files[line_info[:file_id]][:end] = index
      end
    end
  
    files
  end
  
  def read_lines(filename)
    File.readlines(filename).map do |line|
      { :content => line }
    end
  end