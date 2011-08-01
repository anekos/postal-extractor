#!/usr/bin/ruby
# vim:set fileencoding=utf-8 :

require 'pathname'
require 'fileutils'

module GoPostal
  class SAKFileEntry
    attr_reader :name

    def initialize (io, name, position)
      @io = io
      @name = name
      @position = position
    end

    def content
      @io.seek(@position.begin)
      @io.read(@position.end - @position.begin)
    end

    def extract (io)
      io = File.open(io, 'w') if Pathname === io or String === io
      io.binmode
      io.write(self.content)
    end
  end

  class SAKFile
    Index = Struct.new(:name, :offset)

    include Enumerable

    def initialize (io)
      @io =
        case io
        when File
          io
        when String, Pathname
          File.open(io)
        else
          raise "Bad argument for #{self.class}#new"
        end

      @entries = []
      @names = {}

      @io.binmode
      @io.seek(0x08)

      @size = @io.read(4).unpack('S').first

      indexes =
        (0...@size).map { Index.new( @io.readline(0.chr)[0..-2], @io.read(4).unpack('I').first) }

      indexes.each_with_index do
        |index, i|
        last =
          if i < @size - 1
            indexes[i + 1].offset
          else
            @io.size - 1
          end

        indexes.sort_by! {|entry| entry.offset }

        entry = SAKFileEntry.new(@io, index.name, index.offset...last)

        @entries << entry
        @names[index.name] = entry
      end
    end

    def each
      @entries.each do
        |entry|
        yield entry
      end
    end

    def extract (dir, fail_if_exists = true)
      dir = Pathname.new(dir) unless Pathname === dir
      self.each do
        |entry|
        filepath = dir + entry.name.sub(/\A\//, '')
        raise "The file already exists: #{filepath}" if fail_if_exists and filepath.exist?
        FileUtils.mkdir_p(filepath.parent)
        entry.extract(filepath)
      end
    end

    def [] (index)
      if Fixnum === index
        @entries[index]
      else
        @names[index]
      end
    end
  end
end

if __FILE__ == $0
  unless ARGV.size === 2
    STDERR.puts("Usage: #{Pathname.new($0).basename} <SAK_FILE_1> <SAK_FILE_2> ... <SAK_FILE_N> <OUTPUT_DIRECTORY>")
    exit 1
  end

  src_files, output_dir = ARGV[0..-2], ARGV.last

  src_files.each do
    |src_file|
    GoPostal::SAKFile.new(src_file).extract(output_dir)
  end
end
