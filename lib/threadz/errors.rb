module Threadz
  # Generic class that all Threadz errors are a subclass of.
  class ThreadzError < StandardError; end

  # Thrown when a Job is the origin of an error.  The original set of errors are available in the #errors field.
  class JobError < ThreadzError
    attr_reader :errors
    def initialize(errors)
      super("One or more jobs failed due to errors (see #errors)")
      @errors = errors
    end
  end
end