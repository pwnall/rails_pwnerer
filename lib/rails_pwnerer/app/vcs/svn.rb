# checks out and updates the application from a Subversion repository

require 'English'
require 'fileutils'
require 'pathname'
require 'rexml/document'

class RailsPwnerer::App::Svn
  include RailsPwnerer::Base
    
  # remove any files not in SVN in the application dir
  def cleanup_app_dir(app_name, instance_name, target_dir, app_name_is_dir = false)
    Dir.chdir(app_name_is_dir ? app_name : RailsPwnerer::Config[app_name, instance_name][:app_path]) do
      # get a listing of what happened in that directory
      xml_status = `svn status --xml #{target_dir}`
      xsdoc = REXML::Document.new xml_status
      
      xsdoc.root.elements['target'].each_element do |e|
        next unless e.name == 'entry'
        next unless e.elements['wc-status'].attribute('item').value == 'unversioned'
        
        FileUtils.rm_r e.attribute('path').value
      end
    end
  end
  
  # clean up the application directory by removing caches 
  def cleanup_app_caches(app_name, instance_name, app_name_is_dir = false)
    # TODO: this is almost-duplicated in git.rb -- pull up somewhere
    app_path = app_name_is_dir ? app_name : RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.svn'))
    
    # TODO: learn how Rails caches work and kill those too
    ['app', 'db', 'lib', 'public/images',
    'public/javascripts', 'public/stylesheets', 'script',
    'test', 'tmp', 'vendor'
    ].each { |dir| cleanup_app_dir app_name, instance_name, dir, app_name_is_dir }
  end
  
  # reverts the config changes made by rpwn, so svn update doesn't get confused
  def revert_config_changes(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      ['config', 'Gemfile'].each do |dir|
        Kernel.system "svn revert --recursive #{dir}"
      end
    end
  end
    
  def svn_update(app_name, instance_name)
    Dir.chdir RailsPwnerer::Config[app_name, instance_name][:app_path] do
      print "Doing SVN update, please enter your password if prompted...\n"
      success = Kernel.system 'svn update'
      unless success
        print "Update failed, performing svn cleanup and re-trying\n"
        Kernel.system 'svn cleanup'
        print "Doing SVN update, please enter your password if prompted...\n"
        Kernel.system 'svn update'
      end
    end
  end

  def checkout(remote_path, app_name, instance_name)
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    return :next unless remote_path =~ /svn.*\:\/\// or remote_path =~ /http.*\:\/\/.*svn/
    
    print "Doing SVN checkout, please enter your password if prompted...\n"
    system "svn co #{remote_path} #{app_path}"

    # check that we really checked out a Rails app
    return check_rails_root(app_path) ? :ok : false
  end
  
  def update(app_name, instance_name)
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.svn'))
    
    # TODO: maybe backup old version before issuing the svn update?
    
    cleanup_app_caches app_name, instance_name
    revert_config_changes app_name, instance_name
    svn_update app_name, instance_name
  end  
  
  def update_prefetch(app_name, instance_name)
    app_path = RailsPwnerer::Config[app_name, instance_name][:app_path]
    return unless File.exists?(File.join(app_path, '.svn'))
    
    # TODO: figure out a way to prefetch using SVN (hidden local repo mirror?)
  end
end
