# Handles reading and extracting command description and usage from file libraries
# comment descriptions inspired by http://github.com/pragdavespc/rake/commit/45231ac094854da9f4f2ac93465ed9b9ca67b2da
module Boson::Inspector
  extend self
  # returns file and line no of method given caller array
  def find_method_locations(stack)
    if (line = stack.find {|e| e =~ /in `load_source'/ })
      (line =~ /^(.*):(\d+)/) ? [$1, $2.to_i] : nil
    end
  end

  def add_meta_methods
    ::Module.module_eval %[
      def new_method_added(method)
        if @desc
          @_descriptions[method.to_s] = @desc
          @desc = nil
        end
        if @opts
          @_options[method.to_s] = @opts
          @opts = nil
        end
        if @opts.nil? || @desc.nil?
          @_method_locations ||= {}
          if (result = Boson::Inspector.find_method_locations(caller))
            @_method_locations[method.to_s] = result
          end
        end
      end

      def options(opts)
        @_options ||= {}
        @opts = opts
      end

      def desc(description)
        @_descriptions ||= {}
        @desc = description
      end

      alias_method :_old_method_added, :method_added
      alias_method :method_added, :new_method_added
    ]
  end

  def remove_meta_methods
    ::Module.module_eval %[
      remove_method :desc
      alias_method :method_added, :_old_method_added
    ]
  end

  def description_from_file(file_string, line)
    lines = file_string.split("\n")
    line -= 2
    (lines[line] =~ /^\s*#\s*(?!\s*options)(.*)/) ? $1 : nil
  end

  def options_from_file(file_string, line)
    lines = file_string.split("\n")
    start_line = line - 3
    (start_line..start_line +1).find {|line|
      if options = (lines[line] =~ /^\s*#\s*options\s*(.*)/) ? $1 : nil
        options = "{#{options}}" unless options[/^\s*\{/]
        return begin eval(options); rescue(Exception); nil end
      end
    }
  end

  def command_usage(name)
    return "Command not loaded" unless (command = Boson.command(name.to_s) || Boson.command(name.to_s, :alias))
    return "Library for #{command_obj.name} not found" unless lib = Boson.library(command.lib)
    return "File for #{lib.name} library not found" unless File.exists?(lib.library_file || '')
    tabspace = "[ \t]"
    file_string = Boson::FileLibrary.read_library_file(lib.library_file)
    if match = /^#{tabspace}*def#{tabspace}+#{command.name}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      "#{name} "+ (match.to_a[2] || '').split(/\s*,\s*/).map {|e| "[#{e}]"}.join(' ')
    else
      "Command not found in file"
    end
  end
end