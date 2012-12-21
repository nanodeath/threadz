['atomic_integer', 'sleeper', 'errors'].each { |lib| require File.join(File.dirname(__FILE__), lib) }

module Threadz
  # A batch is a (typically related) collection of jobs that execute together on
  # the attached thread pool.  The calling thread can be signaled when the
  # batch has completed executing, or a block can be executed.
  # The easiest way to create a batch is with the ThreadPool method ThreadPool#new_batch:
  #  tp = Threadz::ThreadPool.new
  #  tp.new_batch(args)
  # The options to new_batch get passed to Batch#initialize.
  class Batch
    # Creates a new batch attached to the given threadpool.  A number of options
    # are available:
    # :latent [false]:: If latent, none of the jobs in the batch will actually start
    #                   executing until the #start method is called.
    # :max_retries [0]:: Specifies the maximum number of times to automatically retry a failed
    #                    job.  Defaults to 0.
    # :error_handler [nil]:: Specifies the error handler to be invoked in the case of an error.
    #                        It will be called like so: handler.call(error, control) where +error+ is the underlying error and
    #                        +control+ is a Control for the job that had the error.
    def initialize(threadpool, opts={})
      @threadpool = threadpool
      @job_lock = Mutex.new
      @jobs_count = AtomicInteger.new(0)
      @when_done_callbacks = []
      @sleeper = ::Threadz::Sleeper.new

      @error_lock = Mutex.new # Locked whenever the list of errors is read or modified
      @job_errors = []
      @error_handler_errors = []

      @error_handler = opts[:error_handler]
      if @error_handler && !@error_handler.respond_to?(:call)
        raise ArgumentError.new("ErrorHandler must respond to #call")
      end

      @max_retries = opts[:max_retries] || 0

      @verbose = opts[:verbose]

      ## Options

      #latent
      @latent = opts.key?(:latent) ? opts[:latent] : false
      if(@latent)
        @started = false
      else
        @started = true
      end
      @job_queue = Queue.new if @latent
    end

    # Add a new job to the batch.  If this is a latent batch, the job won't
    # be scheduled until the batch is #start'ed; otherwise it may start
    # immediately.  The job can be anything that responds to +call+ or an
    # array of objects that respond to +call+.
    def push(job)
      if job.is_a? Array
        job.each { |j| self.push(j) }
      elsif job.respond_to? :call
        @jobs_count.increment
        if @latent && !@started
          @job_queue << job
        else
          send_to_threadpool(job)
        end
      else
        raise "Not a valid job: needs to support #call"
      end
    end

    alias << push

    # Blocks until the batch is done processing.
    # +:timeout+ [nil]:: If specified, will only wait for this many seconds
    #                    for the batch to finish.  Typically used with #completed?
    def wait_until_done(opts={})
      raise "Threadz: thread deadlocked because batch job was never started" if @latent && !@started

      timeout = opts.key?(:timeout) ? opts[:timeout] : 0
      @sleeper.wait(timeout) unless completed?
      errors = self.job_errors
      if !errors.empty? && !@error_handler
        raise JobError.new(errors)
      end
    end

    # Returns true iff there are no jobs outstanding.
    def completed?
      return @jobs_count.value == 0
    end

    # Returns the list of errors that occurred in the jobs
    def job_errors
      @error_lock.synchronize { @job_errors.dup }
    end

    # Returns the list of errors that occurred in the error handler
    def error_handler_errors
      @error_lock.synchronize { @error_handler_errors.dup }
    end

    # If this is a +latent+ batch, start processing all of the jobs in the queue.
    def start
      @job_lock.synchronize do  # in case another thread tries to push new jobs onto the queue while we're starting
        if @latent && !@started
          @started = true
          until @job_queue.empty?
            job = @job_queue.pop
            send_to_threadpool(job)
          end
        end
      end
    end

    # Execute a given block when the batch has finished processing.  If the batch
    # has already finished executing, execute immediately.
    def when_done(&block)
      call_block = false
      @job_lock.synchronize do
        if completed?
          call_block = true
        else
          @when_done_callbacks << block
        end
      end
      yield if call_block
    end

    private
    def handle_done
      @sleeper.broadcast
      callbacks = nil
      @job_lock.synchronize do
        callbacks = @when_done_callbacks.dup
        @when_done_callbacks.clear
      end

      callbacks.each { |b|  b.call }
    end

    def send_to_threadpool(job)
      @threadpool.process do
        control = Control.new(job)
        retries = 0
        begin
          job.call
        rescue StandardError => e
          @error_lock.synchronize { @job_errors << e }
          control.job_errors << e
          if @error_handler
            begin
              @error_handler.call(e, control)
            rescue StandardError => e2
              # Who handles the error handler?!
              $stderr.puts %{Exception in error handler: #{e}} if @verbose
              @error_lock.synchronize { @error_handler_errors << e2 }
              control.error_handler_errors << e2
            end
            retries += 1
            retry unless retries >= @max_retries
          end
        end
        should_handle_done = false
        @job_lock.synchronize do
          @jobs_count.decrement
          should_handle_done = completed?
        end
        handle_done if should_handle_done
      end
    end
  end
end
