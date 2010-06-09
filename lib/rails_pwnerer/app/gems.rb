# sets up the application gems

class RailsPwnage::App::Gems
  include RailsPwnage::Base
  
  def update(app_name, instance_name)
    app_config = RailsPwnage::Config[app_name, instance_name]
    
    Dir.chdir app_config[:app_path] do
      # Phase 1: app-directed install
      if !File.exist?('Gemfile') && app_config[:gems]
        # Can be specified as comma-separated string or array.
        if app_config[:gems].respond_to? :to_str
          install_gems = app_config[:gems].split(',')
        else
          install_gems = app_config[:gems]
        end
        install_gems.each do |gem_name|
          begin
            install_gem gem_name unless gem_exists? gem_name
          rescue Exception
          end
        end
      end
    
      # Phase 2: bundler / rails install
      # Install the gems needed by the app.
      if File.exist? 'Gemfile'
        File.open('Gemfile', 'a') { |f| f.write "\ngem 'thin'\n"}
        system "bundle unlock"
        system "bundle install"
        system "bundle lock"
      else
        system "rake gems:install RAILS_ENV=production"
      end
    end    
  end

  def setup(app_name, instance_name)
    update(app_name, instance_name)
  end
end
