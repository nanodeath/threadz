module Threadz
	class JobError < StandardError
		attr_reader :errors
		def initialize(errors)
			super("One or more jobs failed due to errors (see #errors)")
			@errors = errors
		end
	end
end