$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

require 'net/http'

describe Threadz do
  describe Threadz::ThreadPool do
    before(:each) do
      @T = Threadz::ThreadPool.new
    end

#    it "should support process" do
#      i = 0
#      3.times do
#        @T.process { i += 1}
#      end
#      sleep 0.1
#
#      i.should == 3
#    end
#
#    it "should support creating batches" do
#      i = 0
#
#      lambda { @T.new_batch }.should_not raise_error
#      lambda { @T.new_batch(:latent => true) }.should_not raise_error
#    end
#
    it "should perform well for IO jobs" do
      urls = []
      urls << "http://www.google.com/" << "http://www.yahoo.com/" << 'http://www.microsoft.com/'
      urls << "http://www.cnn.com/" << "http://slashdot.org/" << "http://www.mozilla.org/"
      urls << "http://www.ubuntu.com/" << "http://github.com/"
      time_single_threaded = Time.now

      begin
        urls.each do |url|
          response = Net::HTTP.get_response(URI.parse(url))
          body = response.body
        end

        time_single_threaded = Time.now - time_single_threaded

        time_multi_threaded = Time.now
        b = @T.new_batch
        (urls * 5).each do |url|
          b << Proc.new do
            response = Net::HTTP.get_response(URI.parse(url))
            body = response.body
          end
        end

        b.wait_until_done
        time_multi_threaded = Time.now - time_multi_threaded

        time_multi_threaded.should < time_single_threaded

      rescue SocketError
        pending "pending working internet connection"
      end
    end
#
#    it "shouldn't perform badly on computationally intensive tasks" do
#      time_single_threaded = Time.now
#
#      i = 0
#      10_000_000.times { i += 1 }
#
#      time_single_threaded = Time.now - time_single_threaded
#
#      i.should == 10_000_000
#      i = 0
#
#      time_multi_threaded = Time.now
#
#      b = @T.new_batch
#      10.times do
#        b << lambda { 1_000_000.times { i += 1 } }
#      end
#      b.wait_until_done
#
#      time_multi_threaded = Time.now - time_multi_threaded
#
#      i.should == 10_000_000
#
#      time_multi_threaded.should <= time_single_threaded * 1.25
#    end

#    describe Threadz::ThreadPool::Batch do
#      it "should support jobs" do
#        i = 0
#        b = @T.new_batch
#        10.times do
#          b << lambda { i += 1 }
#          b << Proc.new { i += 1 }
#        end
#        b.wait_until_done
#
#        i.should == 20
#      end
#
#      it "should support arrays of jobs" do
#        i = 0
#        b = @T.new_batch
#        b << [lambda { i += 2}, lambda { i -= 1}]
#        b << [lambda { i += 2}]
#        b << lambda { i += 1 }
#        b.wait_until_done
#
#        i.should == 4
#      end
#
#      it "should support reuse" do
#        i = 0
#        b = @T.new_batch
#        b << [lambda { i += 2}, lambda { i -= 1}, lambda { i -= 2 }]
#        b.wait_until_done
#
#        i.should == -1
#
#        b << [lambda { i += 9}, lambda { i -= 3}, lambda { i -= 4 }]
#        b.wait_until_done
#
#        i.should == 1
#      end
#
#      it "should play nicely with instance variables" do
#        @i = 0
#        b = @T.new_batch
#        b << [lambda { @i += 2}, lambda { @i -= 1}]
#        b << lambda { @i += 2}
#        b.wait_until_done
#
#        @i.should == 3
#      end
#
#      it "should support latent option correctly" do
#        i = 0
#        b = @T.new_batch(:latent => true)
#        b << lambda { i += 1 }
#        b << lambda { i -= 1 }
#        b << [lambda { i += 2}, lambda { i -= 1}]
#
#        i.should == 0
#
#        sleep 0.1
#
#        i.should == 0
#
#        b.start
#        b.wait_until_done
#
#        i.should == 1
#      end
#
#      it "should support waiting with timeouts" do
#        i = 0
#        b = @T.new_batch
#        b << lambda { i += 1 }
#        b << lambda { i -= 1 }
#        b << [lambda { i += 2}, lambda { 500000000.times { i += 1}}]
#        t = Time.now
#        timeout = 0.2
#        b.wait_until_done(:timeout => timeout)
#
#        b.completed?.should be_false
#        (Time.now - t).should >= timeout
#        i.should > 2
#      end
#
#      it "should support 'completed?' even without timeouts" do
#        i = 0
#        b = @T.new_batch
#        b << lambda { i += 1 }
#        b << lambda { i -= 1 }
#        b << [lambda { i += 2}, lambda { sleep 0.01 while i < 10 }]
#
#        b.completed?.should be_false
#
#        sleep 0.1
#
#        b.completed?.should be_false
#
#        i = 10
#        sleep 0.1
#
#        b.completed?.should be_true
#      end
#
#      it "should support 'push'" do
#        i = 0
#        b = @T.new_batch
#        b.push(lambda { i += 1 })
#        b.push([lambda { i += 1 }, lambda { i += 1 }])
#        b.wait_until_done
#
#        i.should == 3
#      end
#
#      it "should support 'when_done'" do
#        i = 0
#        when_done_executed = false
#        b = @T.new_batch :latent => true
#
#        100.times { b << lambda { i += 1 } }
#
#        # Hmm, no guarantees that b hasn't completed by now, and can't wrap in
#        # Thread#exclusive because #when_done calls that too.
#        b.when_done { when_done_executed = true }
#
#        when_done_executed.should be_false
#
#        b.start
#
#        sleep(0.1)
#
#        b.completed?.should be_true
#        when_done_executed.should be_true
#      end
#
#      it "should call 'when_done' immediately when batch is already done" do
#        i = 0
#        when_done_executed = false
#        b = @T.new_batch
#
#        Thread.exclusive do
#          100.times { b << lambda { i += 1 } }
#        end
#
#        b.wait_until_done
#
#        b.completed?.should be_true
#
#        b.when_done { when_done_executed = true }
#
#        when_done_executed.should be_true
#      end
#
#      it "should support multiple 'when_done' blocks" do
#        i = 0
#        when_done_executed = 0
#        b = @T.new_batch
#
#        # We're not testing what happens when 'when_done' is called and
#        # the batch is already finished, so wrapping in Thread#exclusive
#        Thread.exclusive do
#          100.times { b << lambda { i += 1 } }
#        end
#
#        3.times { b.when_done { when_done_executed += 1 } }
#
#        sleep(0.1)
#
#        b.completed?.should be_true
#        when_done_executed.should == 3
#      end

#      it "shouldn't fail under load" do
#        jobs = 1000
#        times_per_job = 100000
#        i = 0
#
#        b1 = @T.new_batch(:latent => true)
#        b2 = @T.new_batch(:latent => true)
#
#        jobs.times do
#          b1 << lambda { times_per_job.times { i += 1 } }
#          b2 << lambda { times_per_job.times { i -= 1 } }
#        end
#
#        b1.start
#        b2.start
#
#        b1.wait_until_done
#        b2.wait_until_done
#
#        i.should == 0
#      end
#    end
  end
end