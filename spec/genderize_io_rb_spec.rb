require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "GenderizeIoRb" do
  it "can detect various names" do
    GenderizeIoRb.new do |gir|
      res = gir.info_for_name("kasper")
      res.name.should eql("kasper")
      res.gender.should eql("male")
      res.from_http_request?.should eq true
      
      res = gir.info_for_name("christina")
      res.name.should eql("christina")
      res.gender.should eql("female")
      res.from_http_request?.should eq true
    end
  end
  
  it "should accept a block to destroy automatically" do
    gir = GenderizeIoRb.new{ |gir| }
    gir.destroyed?.should eq true
  end
  
  it "can use a db cache" do
    require "baza"
    require "tmpdir"
    require "sqlite3"
    
    Baza::Db.new(
      :type => "sqlite3",
      :path => "#{Dir.tmpdir}/genderize_io_rb_spec_#{Time.now.to_f.to_s}.sqlite3",
      :debug => false
    ) do |db|
      GenderizeIoRb.new(:cache_db => db) do |gir|
        res = gir.info_for_name("kasper")
        res.name.should eql("kasper")
        res.from_http_request?.should eq true
        
        res = gir.cache_db.select(:genderize_io_rb_cache, "name" => "kasper")
        
        count = 0
        res.each do |data|
          data[:name].should eql("kasper")
          count += 1
        end
        
        count.should > 0
        
        expect {
          gir.cache_db.insert(:genderize_io_rb_cache, :name => "kasper")
        }.to raise_error
        
        res = gir.info_for_name("kasper")
        res.name.should eql("kasper")
        res.from_cache_db?.should eq true
      end
    end
  end
  
  it "should raise errors when a name is not found" do
    GenderizeIoRb.new do |gir|
      expect {
        gir.info_for_name("ksldfjslkjfweuir")
      }.to raise_error(GenderizeIoRb::Errors::NameNotFound)
    end
  end
  
  it "can do a multi-name request to speed it up with partly cache from a database" do
    require "baza"
    require "tmpdir"
    require "sqlite3"
    
    path = "#{Dir.tmpdir}/genderize_io_rb_spec_#{Time.now.to_f.to_s}.sqlite3"
    File.unlink(path) if File.exists?(path)
    
    Baza::Db.new(
      :type => "sqlite3",
      :path => path,
      :debug => false
    ) do |db|
      GenderizeIoRb.new(:cache_db => db, :debug => false) do |gir|
        results = gir.info_for_names(["kasper", "christina", "asdjkvujksuhdv"])
        
        results[0].name.should eq "kasper"
        results[0].gender.should eq "male"
        results[0].from_http_request?.should eq true
        
        results[1].name.should eq "christina"
        results[1].gender.should eq "female"
        results[1].from_http_request?.should eq true
        
        results[2].is_a?(::GenderizeIoRb::Errors::NameNotFound).should eq true
        results[2].name.should eq "asdjkvujksuhdv"
        
        
        results = gir.info_for_names(["kasper", "charlotte", "bsdjkvujksuhdv"])
        
        results[0].name.should eq "kasper"
        results[0].gender.should eq "male"
        results[0].from_cache_db?.should eq true
        
        results[1].name.should eq "charlotte"
        results[1].gender.should eq "female"
        results[1].from_http_request?.should eq true
        
        results[2].is_a?(::GenderizeIoRb::Errors::NameNotFound).should eq true
        results[2].name.should eq "bsdjkvujksuhdv"
      end
    end
  end
end
