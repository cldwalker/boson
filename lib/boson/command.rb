module Boson
  class Command < ::Hash
    def self.create(name, library=nil)
      hash = (Boson.config[:commands][name] || {}).merge({:name=>name, :lib=>library.to_s})
      new.replace hash
    end

    def name; self[:name]; end
    def alias; self[:alias]; end
    def lib; self[:lib]; end
  end
end