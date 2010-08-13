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
  EXTENSIONS = ['', '.rb', '.rbw', '.so', '.bundle', '.dll', '.sl', '.jar']
  handles {|source|
    extensions_glob = "{#{EXTENSIONS.join(',')}}"
    $LOAD_PATH.any? {|dir|
      Dir["#{File.expand_path source.to_s, dir}#{extensions_glob}"].size > 0
    }
  }
end