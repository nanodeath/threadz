require 'thread'

module Threadz
	class AtomicInteger
		def initialize(value)
			@value = value
			@mutex = Mutex.new
		end
		
		def value
			@value
		end
		
		def increment(amount=1)
			# We could use Mutex#synchronize here, but compared to modifying an
			# integer, creating a block is crazy expensive
			@mutex.lock
			@value += amount
			@mutex.unlock
		end

		def decrement(amount=1)
			@mutex.lock
			@value -= amount
			@mutex.unlock
		end
	end
end