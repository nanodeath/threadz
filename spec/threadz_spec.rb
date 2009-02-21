require 'spec_helper'

describe Threadz do
  describe Threadz::ThreadPool do
    before(:each) do
      @T = ThreadPool.new
    end

    it "should support batches" do
      i = 0
      b = T.new_batch
      b << lambda { i += 1 }
      b << lambda { i -= 1 }
      b << [lambda { i += 2}, lambda { i -= 1}]
      b.wait_until_done
      i.should == 1
    end

    it "should support latent batches" do
      i = 0
      b = T.new_batch :latent => true
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

    it "should support batches + waiting with timeouts" do
      i = 0
      b = T.new_batch
      b << lambda { i += 1 }
      b << lambda { i -= 1 }
      b << [lambda { i += 2}, lambda { 50000000.times {}}]
      
      b.wait_until_done :timeout => 0.5
      if b.completed?
        puts "batch done"
      else
        puts "batch not done"
      end
    end
  end
end