module Boson
  # This class manages indexing/storing all commands and libraries. See RepoIndex for details
  # about the index created for each Repo.
  module Index
    extend self
    # Array of indexes, one per repo in Boson.repos.
    def indexes
      @indexes ||= Boson.repos.map {|e| RepoIndex.new(e) }
    end

    # Updates all repo indexes.
    def update(options={})
      indexes.each {|e| e.update(options) }
    end

    #:stopdoc:
    def read
      indexes.each {|e| e.read }
    end

    def find_library(command)
      indexes.each {|e|
        lib = e.find_library(command)
        return lib if lib
      }
      nil
    end

    def commands
      indexes.map {|e| e.commands}.flatten
    end

    def libraries
      indexes.map {|e| e.libraries}.flatten
    end

    def all_main_methods
      indexes.map {|e| e.all_main_methods}.flatten
    end
    #:startdoc:
  end
end