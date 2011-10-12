# Invoked when the gem is installed. Hack to get a post-install hook.

require 'rubygems'


# Cheat to get the gem binaries installed in the user's path even on Debians.
['rpwn', 'rpwnctl', 'rpwndev'].each do |file|
  bin_path = "/usr/bin/#{file}"
  unless File.exists? bin_path
    source_path = File.expand_path "../../../bin/#{file}", __FILE__
    Kernel.system "ln -s #{source_path} #{bin_path}"
  end

  File.chmod((File.stat(binpath).mode | 0755), binpath) rescue nil
end

# Make the gem readable and runnable by anyone.
#
# This is a work-around for systems with messed up permission masks.
def openup(path)
  if File.file?(path)
    File.chmod((File.stat(path).mode | 0755), path) rescue nil
    return
  end
  
  Dir.foreach(path) do |entry|
    next if ['.', '..'].include? entry
    openup File.join(path, entry)
  end  
end
base_path = File.expand_path "../../..", __FILE__
openup base_path

# We really shouldn't be abusing rubygems' root. Then again, the Debian
# maintainers shouldn't be abusing the patience of Ruby developers.

# Now trick rubygems and echoe into believing that a gem got installed and
# everything is good.
ext_binary =  'rpwn_setup_notice' + (Gem.win_platform? ? '.dll' : '.so')
File.open(ext_binary, 'w') { |f| }
File.open('Makefile', 'w') do |f|
  f.write "# target_prefix = #{ext_binary}\nall:\n\ninstall:\n\n"
end
