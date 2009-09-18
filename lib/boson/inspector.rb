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

  @mod_store ||= {}
  def store(mod=@current_module)
    @mod_store[mod]
  end

  def current_module=(mod)
    @current_module = mod
    @mod_store[mod] ||= {}
  end

  def new_method_added(mod, meth)
    self.current_module = mod
    store[:descriptions][meth.to_s] = store[:desc] if store[:desc]
    store[:options][meth.to_s] = store[:opts] if store[:opts]

    if store[:opts].nil? || store[:desc].nil?
      store[:method_locations] ||= {}
      if (result = find_method_locations(caller))
        store[:method_locations][meth.to_s] = result
      end
    end
    store[:desc] = nil if store[:desc]
    store[:opts] = nil if store[:opts]
    scrape_arguments(meth)
  end

  def scrape_arguments(meth)
    if @current_module.instance_of?(Module) && ((store[:options] && store[:options].key?(meth.to_s)) ||
      options_in_file?(meth.to_s))
      store[:method_args] ||= {}

      o = Object.new
      o.extend(@current_module)
      # private methods return nil
      if (val = Boson::ArgumentInspector.determine_method_args(meth, @current_module, o))
        store[:method_args][meth.to_s] = val
      end
    end
  end

  def options_in_file?(meth)
    return false if !(method_location = store[:method_locations] && store[:method_locations][meth])
    File.exists?(method_location[0]) && options_from_file(Boson::FileLibrary.read_library_file(method_location[0]), method_location[1])
  end

  def options(mod, opts)
    store(mod)[:options] ||= {}
    store(mod)[:opts] = opts
  end

  def desc(mod, description)
    store(mod)[:descriptions] ||= {}
    store(mod)[:desc] = description
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
