require "./spec_helper"

describe Hash::Serializable do
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
      "count"      => 123,
      "name"       => "TEST",
      "created_at" => created_at,
    })

    obj.count.should eq 123
    obj.label.should eq "TEST"
    obj.created_at.should eq created_at
  end

  it "captures unmapped hash elements" do
    created_at = Time.local
    obj = TestBasic.new({
      "count"      => 123,
      "name"       => "TEST",
      "created_at" => created_at,
      "extra"      => "that's me!"
    })

    obj.count.should eq 123
    obj.label.should eq "TEST"
    obj.created_at.should eq created_at
    obj.hash_unmapped.empty?.should be_false
    obj.hash_unmapped["extra"]?.should eq "that's me!"
  end

  it "is raises an exception on unmapped keys when Strict is included" do
    e = nil
    begin
      obj = TestStrict.from_hash({"val" => 123})
    rescue e : Exception
    end

    e.should be_nil
    obj.not_nil!.val.should eq 123

    begin
      obj = TestStrict.from_hash({"val" => 456, "extra" => "that's me!"})
    rescue e : Hash::SerializableError
    end

    if e
      e.class.should eq Hash::SerializableError
      e.message.should match /Unknown Hash Key: extra/
    end
  end
end
