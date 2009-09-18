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

  def current_method_has_options?(meth, method_location)
    return false if method_location.nil? || (meth == 'method_added' && method_location[0].include?('libraries/file_library.rb'))
    method_location && File.exists?(method_location[0]) &&
      options_from_file(Boson::FileLibrary.read_library_file(method_location[0]), method_location[1])
  end

  def attribute?(mod, attribute)
    attribute = translate_attr(attribute)
    mod.instance_variable_defined?("@#{attribute}")
  end

  def translate_attr(attribute)
    case attribute.to_sym
    when :descriptions then :_descriptions
    when :options then :_options
    when :method_locations then :_method_locations
    when :method_args then :_method_args
    else
      attribute
    end
  end

  def get_attribute(mod, attribute)
    attribute = translate_attr(attribute)
    mod.instance_variable_get("@#{attribute}")
  end

  def add_meta_methods
    @enabled = true
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

        # if module && options exists for method
        if instance_of?(Module) && (@_options && @_options.key?(method.to_s)) ||
          (@_method_locations && Boson::Inspector.current_method_has_options?(method.to_s, @_method_locations[method.to_s]))

          @_method_args ||= {}
          o = Object.new
          o.extend(self)
          # private methods return nil
          if (val = Boson::ArgumentInspector.determine_method_args(method, self, o))
            @_method_args[method.to_s] = val
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
      remove_method :options
      alias_method :method_added, :_old_method_added
    ]
    @enabled = false
  end

  def enabled?; @enabled; end

  def description_from_file(file_string, line)
    (hash = Boson::Scraper.scrape(file_string, line))[:desc] && hash[:desc].join(" ")
  end

  def options_from_file(file_string, line, mod=nil)
    if (hash = Boson::Scraper.scrape(file_string, line)).key?(:options)
      options = hash[:options].join(" ")
      if mod
        options = "{#{options}}" if !options[/^\s*\{/] && options[/=>/]
        begin mod.module_eval(options); rescue(Exception); nil end
      else
        !!options
      end
    end
  end

  # produces same argument arrays as determine_method_args
  def arguments_from_file(file_string, meth)
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+#{meth}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      (match.to_a[2] || '').split(/\s*,\s*/).map {|e| e.split('=')}
    end
  end
end