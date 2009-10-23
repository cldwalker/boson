# This library requires the given name. This is useful for loading standard libraries,
# non-gem libraries (i.e. rip packages) and anything else in $LOAD_PATH.
#
# Example:
#   >> load_library 'fileutils', :class_commands=>{'cd'=>'FileUtils.cd', 'cp'=>'FileUtils.cp'}
#   => true
#   >> cd '/home'
#   => 0
#   >> Dir.pwd
#   >> '/home'
class Boson::RequireLibrary < Boson::GemLibrary
  handles {|source|
    begin
      Kernel.load("#{source}.rb", true)
    rescue LoadError
      false
    end
  }
end