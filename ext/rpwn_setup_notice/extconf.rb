# invoked when the gem is installed

# cheat to get the gem installed in the right place even on Debians
['rpwn', 'rpwnctl', 'rpwndev'].each do |file|
  binpath = "/usr/bin/#{file}"
  unless File.exists? binpath
    Kernel.system "ln -s #{File.expand_path(__FILE__ + "/../../../bin/#{file}")} #{binpath}"
  end

  File.chmod((File.stat(binpath).mode | 0755), binpath) rescue nil
end

# make the gem readable by anyone (workaround systems with messed up permission masks)
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
base_path = File.expand_path(__FILE__ + "/../../../")
openup(base_path)

# we really shouldn't be abusing rubygems' root; then again, the Debian maintaines shouldn't be
# abusing the patience of Ruby developers

# now trick rubygems into believeing that all is good
File.open('Makefile', 'w') { |f| f.write "all:\n\ninstall:\n\n" }
File.open('rpwn_setup_notice.so', 'w') {}
File.open('rpwn_setup_notice.dll', 'w') {}
