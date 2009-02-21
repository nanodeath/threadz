$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__))
require 'spec_helper'

describe Threadz do
  describe Threadz::ThreadPool do
    before(:each) do
      @T = Threadz::ThreadPool.new
    end

    it "should support batches" do
      i = 0
      b = @T.new_batch
      b << lambda { i += 1 }
      b << lambda { i -= 1 }
      b << [lambda { i += 2}, lambda { i -= 1}]
      b.wait_until_done
      i.should == 1
    end

    it "should support latent batches" do
      i = 0
      b = @T.new_batch :latent => true
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

    it "should support batches and waiting with timeouts" do
      i = 0
      b = @T.new_batch
      b << lambda { i += 1 }
      b << lambda { i -= 1 }
      b << [lambda { i += 2}, lambda { 50000000.times {}}]

      t = Time.now
      timeout = 0.5

      b.wait_until_done :timeout => timeout

      b.completed?.should be_false
      (Time.now - t).should >= 0.5
    end

    it "should support completed even without timeouts" do
      i = 0
      b = @T.new_batch
      b << lambda { i += 1 }
      b << lambda { i -= 1 }
      b << [lambda { i += 2}, lambda { sleep 0.05 while i < 10 }]
      b.completed?.should be_false
      sleep 0.2
      b.completed?.should be_false
      i = 10
      sleep 0.2
      b.completed?.should be_true
    end
  end
end