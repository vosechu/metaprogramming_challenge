require 'rspec'

describe "Counting calls" do

  context "String#size" do
    it "should output the number of calls" do
      out = `COUNT_CALLS_TO='String#size' ruby -r ./lib/solution.rb -e '(1..100).each{|i| i.to_s.size if i.odd? }'`
      out.should eq "String#size called 50 times\n"
    end
  end

  context "B#foo" do
    it "should output the number of calls" do
      out = `COUNT_CALLS_TO='B#foo' ruby -r ./lib/solution.rb -e 'module A; def foo; end; end; class B; include A; end; 10.times{B.new.foo}'`
      out.should eq "B#foo called 10 times\n"
    end
  end

end

describe "Module/function splitting" do

  before(:each) do
    # Use load in this case because we want to repatch things each time
    # FIXME: Is there a way to make rspec force a new binding each time?
    load './lib/solution.rb'
  end

  it "should split functions" do
    CallPatcher.new('String#size').parse.should eq([String, :size, :instance])
  end

  it "should not return classes for as-yet undefined methods" do
    CallPatcher.new('ActiveRecord::Base#find').parse.should eq(["ActiveRecord::Base", "find", nil])
    CallPatcher.new('B#foo').parse.should eq(["B", 'foo', nil])
  end

  it "should understand whether a required method is instance or class" do
    CallPatcher.new('Array#map!').parse.should eq([Array, :map!, :instance])
    CallPatcher.new('String#try_convert').parse.should eq([String, :try_convert, :class])
  end

  it "should return classes if they're required" do
    CallPatcher.new('Base64.encode64').parse.should eq(["Base64", "encode64", nil])
    require 'base64'
    CallPatcher.new('Base64.encode64').parse.should eq([Base64, :encode64, :class])
  end

  it "should return a string if the class exists but not the method" do
    CallPatcher.new('String#happiness').parse.should eq([String, "happiness", nil])
  end

  it "should split into multiple vars" do
    mod, func, instance_or_class = CallPatcher.new('String#size').parse
    mod.should eq(String)
    func.should eq(:size)
    instance_or_class.should eq(:instance)
  end
end

describe "Counting simple things" do
  before(:each) do
    ENV['COUNT_CALLS_TO'] = "String#upcase"
    load './lib/solution.rb'
  end

  # # FIXME: Find a way to unmake these changes each time we run
  # it "should undefine the new method each time" do
  #   "hello".should_not respond_to(:upcase_without_counter)
  # end

  it "should count to 1" do
    $counts.should eq(0)
    "hello".upcase
    $counts.should eq(1)
  end
end

# Capture puts'
# http://stackoverflow.com/a/11349621/203731
def capture_stdout(&block)
  original_stdout = $stdout
  $stdout = fake = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
  fake.string
end