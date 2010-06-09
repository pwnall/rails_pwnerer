require 'fileutils'
require 'net/http'

class RailsPwnerer::Scaffolds::RubyGems
  include RailsPwnerer::Base
  
  # retrieves the URI for a Google "I'm Feeling Lucky" search
  def google_lucky_uri(query)
    uri = URI.parse "http://www.google.com/search?q=#{URI.escape query}&btnI=Lucky"
    response = Net::HTTP.start(uri.host, uri.port) { |http| http.get "#{uri.path}?#{uri.query}" }
    response.header['location']
  end
  
  # retrieves the download URI for a RubyForge project
  def rubyforge_download_uri(project, gem_name = project, extension = ".gem")
    frs_uri = URI.parse google_lucky_uri("#{project} download page")
    frs_contents = Net::HTTP.get frs_uri
    frs_links = frs_contents.scan(/\<a.+href=\"(.+?)\"\>/).flatten.
                  select { |link| link.index('.tgz') && link.index("#{gem_name}-") }
    latest_link = frs_links.sort_by { |n| n.match(/#{gem_name}-(.*)\.#{extension}/)[1] }.last
    return frs_uri.merge(latest_link)
  end
  
  # installs Rubygems on the system
  def install_rubygems
    with_temp_dir(:root => true) do 
      tgz_uri = rubyforge_download_uri('rubygems', 'rubygems', 'tgz')
      file_name = File.basename tgz_uri.path
      loop do
        request_path = tgz_uri.query.to_s.empty? ? tgz_uri.path : "#{tgz_uri.path}?#{tgz_uri.query}"
        response = Net::HTTP.start(tgz_uri.host, tgz_uri.port) { |http| http.get request_path }
        if response.kind_of? Net::HTTPRedirection
          tgz_uri = URI.parse response.header['location']
          next
        end
        File.open(file_name, 'wb') { |f| f.write response.body }
        break
      end
      
      system "tar -xzf #{file_name}" 
      File.unlink file_name
      Dir.chdir(Dir.glob('*').first) do
        system "ruby setup.rb"
      end
    end   
  end
  
  def run
    # get the old path set by pre-go
    old_gems = @@old_gems
    
    # remove the (retarded) Debian gems package and install from source    
    remove_packages %w(rubygems)
    install_rubygems
    
    # patch Ubuntu's broken rubygems installation
    system "cp /usr/bin/gem1.8 /usr/bin/gem"    
    
    # remove the gems that are trailing behind
    new_gems = File.dirname(File.dirname(path_to_gem('sources', '/lib/sources.rb')))
    return if new_gems == old_gems # don't wipe the new dir by mistake
    FileUtils.rm_r old_gems 
  end
  
  def preflight
    # save old lib path, in case we need to wipe it
    # we need to do this because setting up packages might wipe Ubuntu's gems
    @@old_gems = File.dirname(File.dirname(path_to_gem('sources', '/lib/sources.rb')))        
  end
  
  # called before packages get installed
  def self.pre_go
    self.new.preflight
  end
  
  # standalone runner
  def self.go
    self.new.run
  end  
end
