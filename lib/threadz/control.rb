module Threadz
	# A control through which to manipulate an individual job
	class Control
		attr_reader :errors

		def initialize
			@errors = []
			@retry = false
		end

		def try_again(error_limit=Infinity)
			if @errors.size < error_limit
				@retry = true
			end
		end

		def retry?
			@retry
		end

		def reset_retry
			@retry = false
		end
	end
end