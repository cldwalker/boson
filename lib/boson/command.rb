module Boson
  class Command
    def self.create(name, library)
      attributes = (Boson.config[:commands][name] || {}).merge({:name=>name, :lib=>library.to_s})
      attributes[:alias] = Boson.config[:command_aliases][name] if Boson.config[:command_aliases][name]
      new attributes
    end

    def self.create_aliases(commands, lib_module)
      aliases_hash = {}
      select_commands = Boson.commands.select {|e| commands.include?(e.name)}
      select_commands.each do |e|
        if e.alias
          aliases_hash[lib_module.to_s] ||= {}
          aliases_hash[lib_module.to_s][e.name] = e.alias
        end
      end
      Alias.manager.create_aliases(:instance_method, aliases_hash)
    end

    attr_accessor :name, :lib, :alias
    def initialize(hash)
      @name = hash[:name] or raise ArgumentError
      @lib = hash[:lib] or raise ArgumentError
      @alias = hash[:alias] if hash[:alias]
    end
  end
end