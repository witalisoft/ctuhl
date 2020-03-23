SNIPPETS_TEMP_DIR = ENV.fetch('SNIPPETS_TEMP_DIR')
GITHUB_REPOSITORY = ENV.fetch('GITHUB_REPOSITORY')
REPOSITORY_FILE_PREFIX = ENV.fetch('REPOSITORY_FILE_PREFIX')

require_relative 'util'

snippet_show_context = false

ARGV.each do|filename|
  puts "extracting snippets from file '#{filename}'"

  lines = create_lines(filename)
  snippets = extract_snippets(lines)

  snippets.each do |snippet_id,snippet|
    snippet_filename = "#{SNIPPETS_TEMP_DIR}/snippet_#{snippet_id}"
    puts "writing snippet file '#{snippet_filename}'"

    if(!snippet[:start])
      puts "snippet '#{snippet_id}' has no start tag"
      exit
    end

    if(!snippet[:end])
      puts "snippet '#{snippet_id}' has no end tag"
      exit
    end

    start = snippet[:start] + 1
    length = snippet[:end] - snippet[:start] - 1
    indented = false
    indention = ""
    if (lines[start][:indented])
      indented = true
      indention = lines[start][:indention]
    end

    snippet_content = lines[start, length].collect {|line| line[:content] }.join('')
    if File.exist?(snippet_filename)
      puts "snippet #{snippet_filename} already exists, skipping"
      next
    end
    open(snippet_filename, 'w') { |file|
      #line_start = lines[snippet[:start] + 1][:number]
      #line_end = lines[snippet[:end] -1][:number]

      line_start = start + 1
      line_end = start + length - 1

      file.puts "{{< github repository=\"#{GITHUB_REPOSITORY}\" file=\"#{REPOSITORY_FILE_PREFIX}/#{filename}#L#{line_start}-L#{line_end}\" >}}#{File.basename filename}{{< /github >}}"
      file.puts "{{< highlight go \"\" >}}"
      if (snippet_show_context && indented)
        file.puts lines[0, start].reverse.select { |x| !x[:indented] && !x[:empty] }.first[:content]
        file.puts "\n#{indention}[..]\n\n"
      end
      file.puts snippet_content
      if (snippet_show_context && indented)
        file.puts "\n#{indention}[..]\n\n"
        file.puts lines[start, lines.length].select { |x| !x[:indented] && !x[:empty] }.first[:content]
      end
      file.puts '{{< / highlight >}}'
    }
  end
end