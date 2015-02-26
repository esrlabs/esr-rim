module RIM
module Command

class Command
  attr_writer :logger

  def initialize(processor)
    @processor = processor
  end
end
end
end


