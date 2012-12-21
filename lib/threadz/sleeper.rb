require 'thread'
require 'timeout'

module Threadz
	class Sleeper # :nodoc: all
		def initialize
			@waiters = Queue.new
		end
		
		def wait(timeout=0)
			if(timeout == nil || timeout <= 0)
				@waiters << Thread.current
				Thread.stop
				return true
			else
				begin
					@waiters << Thread.current
					status = Timeout::timeout(timeout) {
					  Thread.current[:'__THREADZ_IS_SLEEPING'] = true
					  Thread.stop
					  Thread.current[:'__THREADZ_IS_SLEEPING'] = false
					}
					return true
				rescue Timeout::Error
					return false
				end
			end
		end
		
		def signal
			begin
				begin
					waiter = @waiters.pop(true)
				rescue ThreadError => e
				end
			end while waiter[:'__THREADZ_IS_SLEEPING']
			waiter.wakeup if waiter
		end

		def broadcast
			while !@waiters.empty?
				begin
					@waiters.pop(true).wakeup
				rescue ThreadError => e
				end
			end
		end
	end
end