require 'thread'

module Threadz
	# Related to, or at least named after, Java's AtomicInteger.
	# Provides a thread-safe integer counter thing.
	# The code used in this file, while slightly verbose, is to optimize
	# performance.  Avoiding additional method calls and blocks is preferred.
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
			# We could refactor and just call set here, but it's faster just to write
			# the extra two lines.
			@mutex.lock
			@value -= amount
			@mutex.unlock
		end

		def set(value)
			@mutex.lock
			@value = value
			@mutex.unlock
		end
	end
end