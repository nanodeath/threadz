module Threadz
	# Directives: Special instructions for threads that are communicated via the queue
	class Directive # :nodoc: all
			# The thread that consumes this directive immediately dies
      SUICIDE_PILL = "__THREADZ_SUICIDE_PILL"
	end
end