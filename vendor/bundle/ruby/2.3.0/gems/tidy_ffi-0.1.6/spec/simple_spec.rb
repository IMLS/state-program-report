require 'spec_helper'

describe TidyFFI::Tidy do
  T = TidyFFI::Tidy
  context "public interface" do
    [[:initialize, -2],
     [:clean, 0],
     [:errors, 0]].each do |method, arity|
       it "method #{method} has arity #{arity}" do
         T.instance_method(method).arity.should == arity
       end
     end
  end

  context "simple cleanup" do
    it "clean up text" do
      T.new("test").clean.should =~ %r{<body>\s+test\s+</body>}
      T.new("test").clean.should =~ %r{<meta name="generator" content=.+?Tidy.+?>}m

      T.clean("test").should =~ %r{<body>\s+test\s+</body>}
      T.clean("test").should =~ %r{<meta name="generator" content=.+?Tidy.+?>}m
    end

    it "doesn't die if called twice (bug #27200)" do
      2.times { T.with_options(:show_warnings => false).new("test").clean }
    end
  end

  context "should have method for errors" do
    it "have method for errors" do
      t = T.new("test")
      t.clean
      t.errors.should =~ /Warning/
    end
  end


  context "options validation" do
    it "raises error on invalid option name" do
      TidyFFI::Tidy.validate_options = true
      lambda do
        TidyFFI::Tidy.default_options = {:complete_garbage => true}
      end.should raise_error(TidyFFI::Tidy::InvalidOptionName)
    end

    it "raises error on invalid option value" do
      TidyFFI::Tidy.validate_options = true
      lambda do
        TidyFFI::Tidy.default_options = {:force_output => "utter garbage"}
      end.should raise_error(TidyFFI::Tidy::InvalidOptionValue)
    end

    it 'accepts UTF-8 writter in uppercase' do
      TidyFFI::Tidy.validate_options = true
      expect { TidyFFI::Tidy.default_options = {:char_encoding => "UTF8"} }.not_to raise_error
    end
  end
end
