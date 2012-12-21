module Threadz
  class ThreadzError < StandardError; end

  class JobError < ThreadzError
    attr_reader :errors
    def initialize(errors)
      super("One or more jobs failed due to errors (see #errors)")
      @errors = errors
    end
  end
  class ErrorHandlerError < ThreadzError
    attr_reader :error
    def initialize(error)
      super("An error occurred in the error handler itself (see #error)")
      @error = error
    end
  end
end