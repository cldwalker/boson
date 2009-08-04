module Boson
  class Library < ::Hash
    def initialize(hash)
      super
      replace(hash)
    end

    def add_lib_commands
      if self[:loaded]
        if self[:except]
          self[:commands] -= self[:except]
          self[:except].each {|e| Boson.main_object.instance_eval("class<<self;self;end").send :undef_method, e }
        end
        self[:commands].each {|e| Boson.commands << Manager.create_command(e, self[:name])}
        if self[:commands].size > 0
          create_lib_aliases_or_warn
        end
      end
    end

    def add_library
      if (existing_lib = Boson.libraries.find_by(:name => self[:name]))
        existing_lib.merge!(self)
      else
        Boson.libraries << self
      end
    end

    def create_lib_aliases(commands, lib_module)
      aliases_hash = {}
      select_commands = Boson.commands.select {|e| commands.include?(e[:name])}
      select_commands.each do |e|
        if e[:alias]
          aliases_hash[lib_module.to_s] ||= {}
          aliases_hash[lib_module.to_s][e[:name]] = e[:alias]
        end
      end
      Alias.manager.create_aliases(:instance_method, aliases_hash)
    end

    def create_lib_aliases_or_warn
      if self[:module]
        create_lib_aliases(self[:commands], self[:module])
      else
        if (commands = Boson.commands.select {|e| self[:commands].include?(e[:name])}) && commands.find {|e| e[:alias]}
          $stderr.puts "No aliases created for lib #{self[:name]} because there is no lib module"
        end
      end
    end

    def method_missing(method, *args, &block)
      method = method.to_s
      if method =~ /^(\w+)=$/ && has_key?($1.to_sym)
        self[$1.to_sym] = args.first
      elsif method =~ /^(\w+)$/ && has_key?($1.to_sym)
        self[$1.to_sym]
      else
        super
      end
    end
  end
end
