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

  def set_attribute(mod, attribute, val)
    attribute = translate_attr(attribute)
    mod.instance_variable_set("@#{attribute}", val)
  end

  def get_attribute(mod, attribute)
    attribute = translate_attr(attribute)
    mod.instance_variable_get("@#{attribute}")
  end

  def new_method_added(mod, meth)
    if get_attribute(mod, :desc)
      get_attribute(mod, :descriptions)[meth.to_s] = get_attribute(mod, :desc)
      set_attribute(mod, :desc, nil)
    end

    if get_attribute(mod, :opts)
      get_attribute(mod, :options)[meth.to_s] = get_attribute(mod, :opts)
      set_attribute(mod, :opts, nil)
    end

    if get_attribute(mod, :opts).nil? || get_attribute(mod, :desc).nil?
      set_attribute(mod, :method_locations, {}) unless attribute?(mod, :method_locations)
      if (result = find_method_locations(caller))
        get_attribute(mod, :method_locations)[meth.to_s] = result
      end
    end
    scrape_arguments(mod, meth)
  end

  def scrape_arguments(mod, meth)
    if mod.instance_of?(Module) && (get_attribute(mod, :options) && get_attribute(mod, :options).key?(meth.to_s)) ||
      get_attribute(mod, :method_locations) && current_method_has_options?(meth.to_s, get_attribute(mod, :method_locations)[meth.to_s])
      set_attribute(mod, :method_args, {}) unless Boson::Inspector.attribute?(mod, :method_args)

      o = Object.new
      o.extend(mod)
      # private methods return nil
      if (val = Boson::ArgumentInspector.determine_method_args(meth, mod, o))
        get_attribute(mod, :method_args)[meth.to_s] = val
      end
    end
  end

  def options(mod, opts)
    set_attribute(mod, :options, {}) unless Boson::Inspector.attribute?(mod, :options)
    set_attribute mod, :opts, opts
  end

  def desc(mod, description)
    set_attribute(mod, :descriptions, {}) unless Boson::Inspector.attribute?(mod, :descriptions)
    set_attribute mod, :desc, description
  end

  def add_meta_methods
    @enabled = true
    ::Module.module_eval %[
      def new_method_added(method)
        Boson::Inspector.new_method_added(self, method)
      end

      def options(opts)
        Boson::Inspector.options(self, opts)
      end

      def desc(description)
        Boson::Inspector.desc(self, description)
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