require "spec"
require "../src/hash_serializable"

class TestBasic
  include Hash::Serializable
  include Hash::Serializable::Unmapped(String? | Int32 | Bool | Time)

  property count : Int32

  @[Hash::Field(key: "name")]
  property label : String? = nil

  @[Hash::Field(ignore: true)]
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

class Note
  include Hash::Serializable

  property message : String = "DEFAULT"
end

class Location
  include Hash::Serializable

  @[Hash::Field(key: "lat")]
  property latitude : Float64

  @[Hash::Field(key: "lon")]
  property longitude : Float64

  property note : Note
end

class House
  include Hash::Serializable

  property address : String
  property location : Location?
  property note : Note
end
