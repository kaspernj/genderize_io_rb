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
end
