require "spec"
require "../src/hash_serializable"

class TestBasic
  include Hash::Serializable
  include Hash::Serializable::Unmapped(String? | Int32 | Bool | Time)

  property count : Int32

  @[Hash::Field(key: "name")]
  property label : String? = nil

  @[Hash::Field(ignore_deserialize: true)]
  @created_at_present : Bool = false

  @[Hash::Field(presence: true)]
  property created_at = Time.local

  def created_at_is_defined?
    @created_at_present
  end
end

class TestStrict
  include Hash::Serializable
  include Hash::Serializable::Strict

  property val : Int32
end
