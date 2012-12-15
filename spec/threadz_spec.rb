$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

describe Threadz do
  describe Threadz::ThreadPool do
    before(:each) do
      @T = Threadz::ThreadPool.new
    end

    it "should support process and accept a block" do
      i = 0
      3.times do
        @T.process { i += 1}
      end
      sleep 0.1

      i.should == 3
    end

    it "should support process and accept an arg that responds to :call" do
      i = 0
      3.times do
        @T.process(Proc.new { i += 1} )
      end
      sleep 0.1

      i.should == 3
    end

    it "should support creating batches" do
      i = 0

      lambda { @T.new_batch }.should_not raise_error
      lambda { @T.new_batch(:latent => true) }.should_not raise_error
    end
    
    it "should not crash when killing threads" do
        i = 0
        b = @T.new_batch(:latent => true)
        5000.times do
          b << lambda { i += 1 }
          b << lambda { i -= 1 }
          b << [lambda { i += 2}, lambda { i -= 1}]
        end

        b.start
        b.wait_until_done

		50.times { sleep 0.1 }
    end

    describe Threadz::Batch do
      it "should support jobs" do
        i = 0
        b = @T.new_batch
        10.times do
          b << lambda { i += 1 }
          b << Proc.new { i += 1 }
        end
        b.wait_until_done

        i.should == 20
      end

      it "should support arrays of jobs" do
        i = 0
        b = @T.new_batch
        b << [lambda { i += 2}, lambda { i -= 1}]
        b << [lambda { i += 2}]
        b << lambda { i += 1 }
        b.wait_until_done

        i.should == 4
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

      it "should support latent option" do
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
        b << [lambda { i += 2}, lambda { sleep 0.1 while i < 10 }]

        b.completed?.should be_false

        sleep 0.1

        b.completed?.should be_false

        i = 10

        5.times do
          sleep 1 if !b.completed?
        end

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
        i = ::Threadz::AtomicInteger.new(0)
        when_done_executed = false
        b = @T.new_batch(:latent => true)

        100.times { b << lambda { i.increment } }

        b.when_done { when_done_executed = true }

        when_done_executed.should be_false

        b.start

				Timeout::timeout(10) do
					sleep(0.1) until i.value == 100
				end

				i.value.should == 100
				
        b.completed?.should be_true
        when_done_executed.should be_true
      end

      it "should call 'when_done' immediately when batch is already done" do
        i = 0
        when_done_executed = false
        b = @T.new_batch :latent => true

				100.times { b << lambda { i += 1 } }

				b.start

        b.wait_until_done

        b.completed?.should be_true

        b.when_done { when_done_executed = true }

        when_done_executed.should be_true
      end

      it "should support multiple 'when_done' blocks" do
        i = 0
        when_done_executed = 0
        b = @T.new_batch :latent => true

				100.times { b << lambda { i += 1 } }

        10.times { b.when_done { when_done_executed += 1 } }


				b.start

        b.wait_until_done

        b.completed?.should be_true
        when_done_executed.should == 10
      end

      context "when exceptions occur" do
        it "should throw on #wait_until_done if no exception handler" do
          b = @T.new_batch
          b << lambda { raise }
          expect { b.wait_until_done }.to raise_error(Threadz::JobError)
        end
        it "should execute the exception handler when given (and not throw in #wait_until_done)" do
          error = nil
          b = @T.new_batch :error_handler => lambda { |e, ctrl| error = e }
          b << lambda { raise }
          b.wait_until_done
          error.should_not be_nil
        end
        it "should retry up to the designated number of times" do
          count = 0
          b = @T.new_batch :error_handler => lambda { |e, ctrl| count += 1; ctrl.try_again(3) }
          b << lambda { raise }
          b.wait_until_done
          count.should == 3
        end
        it "should stash exceptions in the #errors field" do
          b = @T.new_batch
          b.errors.should be_empty
          b << lambda { raise }
          expect { b.wait_until_done }.to raise_error(Threadz::JobError)
          b.errors.should_not be_empty
        end
      end
    end
  end
end
