# extends Base with the ability to get input from the user

begin
  require 'rubygems'
  require 'highline'
rescue Exception
  # no highline... tough luck
end

module RailsPwnage::Base
  def prompt_user_for_password(prompt, fail_prompt)
    unless defined?(HighLine)
      print "#{fail_prompt}\n"
      return nil
    end
    
    HighLine.new.ask(prompt) { |question| question.echo = '' }
  end
end
