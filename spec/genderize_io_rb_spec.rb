require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "GenderizeIoRb" do
  it "can detect various names" do
    gir = GenderizeIoRb.new
    
    res = gir.info_for_name("kasper")
    res.name.should eql("kasper")
    res.gender.should eql("male")
    
    res = gir.info_for_name("christina")
    res.name.should eql("christina")
    res.gender.should eql("female")
    
    gir.destroy
  end
  
  it "can use a db cache" do
    require "baza"
    require "tmpdir"
    require "sqlite3"
    
    db = Baza::Db.new(
      :type => "sqlite3",
      :path => "#{Dir.tmpdir}/genderize_io_rb_spec_#{Time.now.to_f.to_s}.sqlite3",
      :debug => false
    )
    
    gir = GenderizeIoRb.new(:cache_db => db)
    
    res = gir.info_for_name("kasper")
    res.name.should eql("kasper")
    
    res = gir.cache_db.select(:genderize_io_rb_cache, {"name" => "kasper"})
    
    count = 0
    res.each do |data|
      data[:name].should eql("kasper")
      count += 1
    end
    
    count.should > 0
    
    expect {
      gir.cache_db.insert(:genderize_io_rb_cache, :name => "kasper")
    }.to raise_error
  end
end
