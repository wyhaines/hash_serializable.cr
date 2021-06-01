require "./spec_helper"

describe Hash::Serializeable do
  # TODO: Write tests

  it "works to create an object without any parameters" do
    obj = TestBasic.new
    
    obj.count.should eq 0
    obj.label.should be_nil
    obj.created_at.should be < Time.local
  end

  it "works to serialize a generic object to a hash" do
    obj = TestBasic.new

    hsh = obj.to_hash
    hsh["count"].should eq 0
    hsh["name"].should be_nil
    hsh["created_at"].as(Time).should be < Time.local
  end

  it "works to instantiate a new obj from a deserialized previous object" do
    obj1 = TestBasic.new
    obj2 = TestBasic.from_hash(obj1.to_hash)
    obj1.count.should eq obj2.count
    obj1.label.should eq obj2.label
    obj1.created_at.should eq obj2.created_at
    obj1.created_at_is_defined?.should be_false
    obj2.created_at_is_defined?.should be_true
  end

  it "from_hash() works" do
    created_at = Time.local
    obj = TestBasic.from_hash({
      "count" => 123,
      "name" => "TEST",
      "created_at" => created_at})

    obj.count.should eq 123
    obj.label.should eq "TEST"
    obj.created_at.should eq created_at
  end

end