$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

describe Threadz do
  describe Threadz::ThreadPool do
    before(:each) do
      @T = Threadz::ThreadPool.new
    end

    it "should support process" do
      i = 0
      3.times do
        @T.process { i += 1}
      end
      sleep 0.1
      
      i.should == 3
    end

    it "should support creating batches" do
      i = 0

      lambda { @T.new_batch }.should_not raise_error
      lambda { @T.new_batch :latent => true }.should_not raise_error
    end

    describe Threadz::ThreadPool::Batch do
      it "should support jobs" do
        i = 0
        b = @T.new_batch
        10.times do
          b << lambda { i += 1 }
        end
        b.wait_until_done

        i.should == 10
      end

      it "should support arrays of jobs" do
        i = 0
        b = @T.new_batch
        b << [lambda { i += 2}, lambda { i -= 1}]
        b << [lambda { i += 2}]
        b.wait_until_done

        i.should == 3
      end

      it "should support reuse" do
        i = 0
        b = @T.new_batch
        b << [lambda { i += 2}, lambda { i -= 1}, lambda { i -= 2 }]
        b.wait_until_done
        
        i.should == -1

        b << [lambda { i += 9}, lambda { i -= 3}, lambda { i -= 4 }]
        b.wait_until_done

        i.should == 1
      end

      it "should play nicely with instance variables" do
        @i = 0
        b = @T.new_batch
        b << [lambda { @i += 2}, lambda { @i -= 1}]
        b << lambda { @i += 2}
        b.wait_until_done

        @i.should == 3
      end

      it "should support latent option correctly" do
        i = 0
        b = @T.new_batch(:latent => true)
        b << lambda { i += 1 }
        b << lambda { i -= 1 }
        b << [lambda { i += 2}, lambda { i -= 1}]

        i.should == 0
        
        sleep 0.1

        i.should == 0

        b.start
        b.wait_until_done

        i.should == 1
      end

      it "should support waiting with timeouts" do
        i = 0
        b = @T.new_batch
        b << lambda { i += 1 }
        b << lambda { i -= 1 }
        b << [lambda { i += 2}, lambda { 500000000.times { i += 1}}]
        t = Time.now
        timeout = 0.2
        b.wait_until_done(:timeout => timeout)

        b.completed?.should be_false
        (Time.now - t).should >= timeout
        i.should > 2
      end

      it "should support 'completed?' even without timeouts" do
        i = 0
        b = @T.new_batch
        b << lambda { i += 1 }
        b << lambda { i -= 1 }
        b << [lambda { i += 2}, lambda { sleep 0.01 while i < 10 }]

        b.completed?.should be_false

        sleep 0.1

        b.completed?.should be_false

        i = 10
        sleep 0.1

        b.completed?.should be_true
      end

      it "should support 'push'" do
        i = 0
        b = @T.new_batch
        b.push(lambda { i += 1 })
        b.push([lambda { i += 1 }, lambda { i += 1 }])
        b.wait_until_done

        i.should == 3
      end

      it "should support 'when_done'" do
        i = 0
        when_done_executed = false
        b = @T.new_batch

        # We're not testing what happens when 'when_done' is called and
        # the batch is already finished, so wrapping in Thread#exclusive
        Thread.exclusive do
          100.times { b << lambda { i += 1 } }

          b.completed?.should be_false
        end

        # Hmm, no guarantees that b hasn't completed by now, and can't wrap in
        # Thread#exclusive because #when_done calls that too.
        b.when_done { when_done_executed = true }

        when_done_executed.should be_false

        sleep(0.1)

        b.completed?.should be_true
        when_done_executed.should be_true
      end

      it "should call 'when_done' immediately when batch is already done" do
        i = 0
        when_done_executed = false
        b = @T.new_batch

        Thread.exclusive do
          100.times { b << lambda { i += 1 } }

          pending if b.completed?
        end

        b.wait_until_done

        b.completed?.should be_true

        b.when_done { when_done_executed = true }
        
        when_done_executed.should be_true
      end

      it "shouldn't fail" do
        jobs = 1000
        times_per_job = 100
        i = 0

        b1 = @T.new_batch(:latent => true)
        b2 = @T.new_batch(:latent => true)
        
        jobs.times do
          b1 << lambda { times_per_job.times { i += 1 } }
          b2 << lambda { times_per_job.times { i -= 1 } }
        end

        b1.start
        b2.start

        b1.wait_until_done
        b2.wait_until_done

        i.should == 0
      end
    end
  end
end