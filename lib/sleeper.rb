require 'thread'

module Threadz
	class Sleeper
		def initialize
			@waiters = Queue.new
		end
		
		def wait(timeout=0)
			if(timeout <= 0)
				@waiters << Thread.current
				Thread.stop
			else
				raise "Not implemented"
			end
		end
		
		def signal
			@waiters.pop(true).wakeup
		end

		def broadcast
			@waiters.pop.wakeup until @waiters.empty?
		end
	end
end