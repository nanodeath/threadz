require 'thread'

class ThreadPool
  KILL_THRESHOLD = 100
  THREADS_BUSY_SCORE = 20 # how much to decrement kill score by when threads are very busy
  THREADS_IDLE_SCORE = 20 # how much to increment kill score by when there are excess idle threads

  def initialize(opts={})
    @min_size = opts[:initial_size] || 4
    @max_size = opts[:maximum_size] || @min_size * 5
    @queue = {}
    @batch_order = Queue.new
    @working_count = {}
    @threads = []
    @min_size.times { spawn_thread }
    @killscore = 0
    @killthreshold = opts[:kill_threshold] || KILL_THRESHOLD
    
    spawn_watch_thread
  end
  
  def process(batch_name, &block)
    batch_name ||= :default
    (@queue[batch_name] ||= []).push block
    @batch_order << batch_name
  end
  
  def wait_until_done(batch_name)
    return if @queue[batch_name].nil? or @working_count[batch_name].nil?
    sleep 0.001 until @queue[batch_name].empty?
    sleep 0.001 until @working_count[batch_name] <= 0
  end
  
  private
  def jobs_queued
    @batch_order.length
  end
  
  def spawn_thread
    @threads << Thread.new do
      while true
        next_batch = @batch_order.pop
        x = nil
        Thread.exclusive do
          x = @queue[next_batch].pop
          @working_count[next_batch] ||= 0
          @working_count[next_batch] += 1
        end
        begin
          x.call
        rescue Exception => e
          puts e.inspect
        ensure
#          Thread.exclusive do
            @working_count[next_batch] -= 1
#          end
        end
        exit if Thread.current[:suicide]
      end
    end
    puts "spawning thread: now thread count is #{@threads.length}" if $DEBUG
  end
  
  def kill_thread
    Thread.exclusive do
      t = @threads.pop
      t[:suicide] = true unless t.nil?
    end
    puts "killing thread: now threadcount is #{@threads.length}" if $DEBUG
  end
  
  def spawn_watch_thread
    @watch_thread = Thread.new do
      while true
        # If there are more threads waiting for work than the minimum number of threads
        if @batch_order.num_waiting > @min_size && @threads.length > @min_size
          @killscore += THREADS_IDLE_SCORE
        # If there are no threads idle and we have room for more
        elsif(@batch_order.num_waiting == 0 && @threads.length < @max_size)
          @killscore -= THREADS_KILL_SCORE
        else
          if(@killscore < 0)
            @killscore += 1
          elsif(@killscore > 0)
            @killscore -= 1
          end
        end
        if @killscore >= @killthreshold
          @killscore = 0
          kill_thread
        end
        if @killscore *-1 >= @killthreshold
          @killscore = 0
          spawn_thread
        end
        sleep 0.01
      end
    end
  end
end

def counter(prefix, to)
  mod = to / 10
  1.upto(to) do |i|
    if i % mod == 0
#      puts prefix + i.to_s
    end
  end
  puts prefix + " is done!"
end

tp = ThreadPool.new :initial_size => 3
max = 100000

j = 0
5.times do
  ("a".."z").each do |l|
    tp.process :foo do
      counter(l, max)
      j += 1
      j -= 1
      j += 1
      puts j
    end
  end
end
puts "waiting"
tp.wait_until_done :foo
puts "done waiting"
#30000000.times {}