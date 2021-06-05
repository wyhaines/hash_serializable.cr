# hash_serializable

It can be useful to be able to serialize and deserialize between hashes
and objects the same way that one can between JSON and objects and YAML
and objects. This implementation is aiming to be feature-consistent with
JSON::Serializable and YAML::Serializable, while working with hashes.

The `Hash::Serializable` module automatically generates methods for serialization when included.

### Example

```crystal
require "hash_serializable"

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
house.location.not_nil!.latitude.should eq 12.3
house.location.not_nil!.longitude.should eq 34.5
house.note.message.should eq "Nice Address"
house.location.not_nil!.note.message.should eq "hmmmm"
house.to_hash.should eq arg
```

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     hash_serializable:
       github: your-github-user/hash_serializable
   ```

2. Run `shards install`

## Usage

Including `Hash::Serializable` will create `#to_hash` and `self.from_hash` methods
on the current class, and a constructor which takes a Hash. By default, `self.from_hash`
will deserialize a Hash into an instance of the object that it is passed to, according
to the definition of the class, and `#to_hash` will serialize the class into a Hash
containing the value of every instance variable, the keys being the instance variable
names.

It will descend through a nested class structure, where variables in one class
point to objects that, in turn, have instance variables. It should also deal correctly
with type unions.

To change how individual instance variables are parsed and serialized, the annotation
`Hash::Field` can be placed on the instance variable. Annotating property, getter, and
setter macros is also allowed.

```
require "hash_serializable"

struct A
  include Hash::Serializable

  @[Hash::Field(key: "my_key")]
  getter a : Int32?
end
```

`Hash::Field` properties:
* **ignore**: if `true` skip this field in serialization and deserialization (by default false)
* **ignore_serialize**: if `true` skip this field in serialization (by default false)
* **ignore_deserialize**: if `true` skip this field in deserialization (by default false)
* **key**: the value of the key in the json object (by default the name of the instance variable)
* **presence**: if `true`, a `@{{key}}_present` instance variable will be generated when the key was present (even if it has a `null` value), `false` by default; this does not declare the `@{{key}}_present` variable for you, so you will be responsible for ensuring that a Bool variable is declared

Deserialization respects default values of variables.

### Extensions: `Hash::Serializable::Strict` and `Hash::Serializable::Unmapped`

If the `Hash::Serializable::Strict` module is included, unknown properties in the Hash
document will raise an exception. By default the unknown properties are silently ignored.

If the `Hash::Serializable::Unmapped` module is included, unknown properties in the Hash
will be stored in a hash with an appropriate type signature. On serialization, any keys inside json_unmapped
will be serialized into the hash, as well.

```
require "hash_serializable"

struct A
  include Hash::Serializable
  include Hash::Serializable::Unmapped
  @a : Int32
end

a = A.from_json(%({"a":1,"b":2})) # => A(@json_unmapped={"b" => 2_i64}, @a=1)
a.to_json                         # => {"a":1,"b":2}
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/wyhaines/hash_serializable/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Kirk Haines](https://github.com/wyhaines) - creator and maintainer
