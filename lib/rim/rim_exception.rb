module RIM

class RimException < Exception
  attr_reader :messages
  
  def initialize(messages)
    if messages.is_a?(String)
      @messages = [messages]
    else
      @messages = messages
    end 
  end
end

end
