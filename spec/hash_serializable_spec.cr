require "./spec_helper"

describe Hash::Serializable do
  it "works to create an object without any parameters" do
    obj = TestBasic.new({"count" => 0})

    obj.count.should eq 0
    obj.label.should be_nil
    obj.created_at.should be < Time.local
  end

  it "works to serialize a generic object to a hash" do
    obj = TestBasic.new({"count" => 0})

    hsh = obj.to_hash
    hsh["count"].should eq 0
    hsh["name"].should be_nil
    hsh["created_at"].as(Time).should be < Time.local
  end

  it "works to instantiate a new obj from a deserialized previous object" do
    obj1 = TestBasic.new({"count" => 0})
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
      "extra"      => "that's me!",
    })

    obj.count.should eq 123
    obj.label.should eq "TEST"
    obj.created_at.should eq created_at
    obj.hash_unmapped.empty?.should be_false
    obj.hash_unmapped["extra"]?.should eq "that's me!"
  end

  it "serialization with unmapped elements populates them back into the hash" do
    created_at = Time.local
    arg = {
      "count"      => 123,
      "name"       => "TEST",
      "created_at" => created_at,
      "extra"      => "that's me!",
    }

    obj = TestBasic.new(arg)
    obj.to_hash.should eq arg
  end

  it "is raises an exception on unmapped keys when Strict is included" do
    e = nil
    begin
      obj = TestStrict.from_hash({"val" => 123})
    rescue e : Exception
    end

    e.should be_nil
    obj.try &.val.should eq 123

    begin
      TestStrict.from_hash({"val" => 456, "extra" => "that's me!"})
    rescue e : Hash::SerializableError
    end

    if e
      e.class.should eq Hash::SerializableError
      e.message.should match /Unknown Hash Key: extra/
    end
  end

  it "round tripping, part 2" do
    h = {"count" => 123, "name" => "Just a test", "created_at" => Time.local}
    test_obj = TestBasic.from_hash(h)
    test_obj.count.should eq h["count"]
    test_obj.label.should eq h["name"]
    test_obj.created_at.should eq h["created_at"]
    test_obj.to_hash.should eq h
  end

  it "allows symbol keys, as well" do
    h = {:count => 0, :name => "Just a test", :created_at => Time.local}
    test_obj = TestBasic.from_hash(h)
    test_obj.count.should eq h[:count]
    test_obj.label.should eq h[:name]
    test_obj.created_at.should eq h[:created_at]
    test_obj.to_hash.should eq h.transform_keys(&.to_s)
  end

  it "works with nested classes/hashes, too" do
    arg = {
      "note" => {
        "message" => "Nice Address",
      },
      "address"  => "Crystal Road 1234",
      "location" => {
        "lat"  => 12.3,
        "lon"  => 34.5,
        "note" => {
          "message" => "hmmmm",
        },
      },
    }
    house = House.from_hash(arg)

    house.is_a?(House).should be_true
    house.address.should eq "Crystal Road 1234"
    house.location.is_a?(Location).should be_true
    house.location.try &.latitude.should eq 12.3
    house.location.try &.longitude.should eq 34.5
    house.note.message.should eq "Nice Address"
    house.location.try &.note.message.should eq "hmmmm"
    house.to_hash.should eq arg
  end

  it "works with defaults for the ivars" do
    arg = {
      "note" => {
        "message" => "Nice Address",
      },
      "address"  => "Crystal Road 1234",
      "location" => {
        "lat"  => 12.3,
        "lon"  => 34.5,
        "note" => {} of String => String,
      },
    }

    house = House.from_hash(arg)
    house.location.try &.note.message.should eq "DEFAULT"
  end

  it "can cast values from hash to object, using both methods and procs" do
    obj = Castit.new({"whatever" => 123, "number" => "456"})
    obj.whatever.should eq "123"
    obj.everything_is_a_number.should eq 456
  end
end
