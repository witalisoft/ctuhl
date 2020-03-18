SNIPPETS_TEMP_DIR = ENV.fetch('SNIPPETS_TEMP_DIR')
FILES_DIR = ENV.fetch('FILES_DIR')

require_relative 'util'

ARGV.each do|filename|
  puts "inserting snippets into file '#{filename}'"

  lines = create_lines(filename)
  snippets = extract_snippets(lines)

  snippets.reverse_each do |snippet_id,snippet|
    snippet_filename = "#{SNIPPETS_TEMP_DIR}/snippet_#{snippet_id}"

    if(!snippet[:start])
      puts "snippet '#{snippet_id}' has no start tag"
      next
    end

    if(!snippet[:end])
      puts "snippet '#{snippet_id}' has no end tag"
      next
    end

    puts "inserting snippet file '#{snippet_filename}' into #{filename}"
    lines[snippet[:start]+1...snippet[:end]]=read_lines(snippet_filename)
  end

  content = lines.collect {|line| line[:content] }.join('')
  File.write(filename, content)

  puts "inserting files into file '#{filename}'"

  lines = create_lines(filename)
  files = extract_files(lines)

  files.reverse_each do |file_id,file|
    insert_filename = "#{FILES_DIR}/#{file_id}"

    if(!file[:start])
      puts "file '#{file_id}' has no start tag"
      next
    end

    if(!file[:end])
      puts "file '#{file_id}' has no end tag"
      next
    end

    puts "inserting file '#{insert_filename}' into #{filename}"

    insert_filename.slice!(FILES_DIR)
    file_lines=[]
    #file_lines.push({ content: "{{% github href=\"#{insert_filename}\" %}}#{File.basename insert_filename}{{% /github %}}\n" })
    file_lines.push({ content: "{{< highlight go \"\" >}}\n" })
    file_lines.push(*read_lines("#{FILES_DIR}/#{insert_filename}"))
    file_lines.push({ content: "{{< / highlight >}}\n" })

    lines[file[:start]+1...file[:end]]=file_lines
  end

  content = lines.collect {|line| line[:content] }.join('')
  File.write(filename, content)
end
