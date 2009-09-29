# Handles getting and setting method metadata acquired by inspectors for libraries.
module Boson
  module Inspector
    extend self
    attr_reader :enabled

    def add_meta_methods
      @enabled = true
      ::Module.module_eval %[
        def new_method_added(method)
          Boson::MethodInspector.new_method_added(self, method)
        end

        def options(opts)
          Boson::MethodInspector.options(self, opts)
        end

        def desc(description)
          Boson::MethodInspector.desc(self, description)
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

    def set_command_metadata(mod, commands_hash, library_file)
      @commands_hash = commands_hash
      @library_file = library_file
      MethodInspector.current_module = mod
      @store = MethodInspector.store
      add_command_descriptions if @store.key?(:descriptions)
      add_command_options if @store.key?(:options)
      add_comment_metadata if @store.key?(:method_locations)
      add_command_args if @store.key?(:method_args)
    end


    def add_command_args
      @store[:method_args].each do |cmd, args|
        if no_command_config_for(cmd, :args)
          (@commands_hash[cmd] ||= {})[:args] = args
        end
      end
    end

    def add_command_options
      @store[:options].each do |cmd, options|
        if no_command_config_for(cmd, :options)
          (@commands_hash[cmd] ||= {})[:options] = options
        end
      end
    end

    def add_comment_metadata
      @store[:method_locations].select {|k,(f,l)| f == @library_file }.each do |cmd, (file, lineno)|
        scraped = CommentInspector.scrape(FileLibrary.read_library_file(file), lineno, MethodInspector.current_module)
        attr_map = {:description=>:desc}
        [:description, :options, :render_options].each do |e|
          if no_command_config_for(cmd, e)
            (@commands_hash[cmd] ||= {})[e] = scraped[attr_map[e] || e]
          end
        end
      end
    end

    def add_command_descriptions
      @store[:descriptions].each do |cmd, description|
        if no_command_config_for(cmd, :description)
          (@commands_hash[cmd] ||= {})[:description] = description
        end
      end
    end

    def no_command_config_for(cmd, attribute)
      !@commands_hash[cmd] || (@commands_hash[cmd] && !@commands_hash[cmd].key?(attribute))
    end
  end
end