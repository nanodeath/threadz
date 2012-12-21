module Threadz
	# A control through which to manipulate an individual job
	class Control
		attr_reader :job
		attr_reader :job_errors
		attr_reader :error_handler_errors

		def initialize(job)
			@job = job
			@job_errors = []
			@error_handler_errors = []
		end
	end
end