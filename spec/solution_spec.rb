require 'rspec'

describe "Counting calls" do

  before(:each) do
    pending
  end

  context "String#size" do
    before(:each) do
      ENV['COUNT_CALLS_TO'] = 'String#size'
      require './lib/solution'
    end

    it "should output the number of calls" do
      out = capture_stdout do
        (1..100).each{|i| i.to_s.size if i.odd? }
      end
      out.should eq 'String#size called 50 times'
    end
  end

  context "B#foo" do
    before(:each) do
      ENV['COUNT_CALLS_TO'] = 'B#foo'
      require './lib/solution'
    end

    it "should output the number of calls" do
      out = capture_stdout do
        module A; def foo; end; end; class B; include A; end; 10.times{B.new.foo}
      end
      out.should eq 'B#foo called 10 times'
    end
  end

end

describe "Module/function splitting" do

  before(:each) do
    require './lib/solution'
  end

  it "should split functions" do
    CallPatcher.parse('Array#map!').should eq(['Array', 'map!'])
    CallPatcher.parse('ActiveRecord::Base#find').should eq(['ActiveRecord::Base', 'find'])
    CallPatcher.parse('Base64.encode64').should eq(['Base64', 'encode64'])
    mod, func = CallPatcher.parse('String#size')
    mod.should eq("String")
    func.should eq("size")
  end
end

describe "Counting simple things" do
  before(:each) do
    require './lib/solution'
  end

  it "should start at 0" do
    $counts.should eq(0)
  end

  it "should count to 1" do
    CallPatcher.patch('String#size')
    "hello".size
    $counts.should eq(1)
  end
end

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