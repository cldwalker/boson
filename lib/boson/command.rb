module Boson
  class Command < ::Hash
    def self.create(name, library=nil)
      hash = (Boson.config[:commands][name] || {}).merge({:name=>name, :lib=>library.to_s})
      new.replace hash
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

    def name; self[:name]; end
    def alias; self[:alias]; end
    def lib; self[:lib]; end
  end
end