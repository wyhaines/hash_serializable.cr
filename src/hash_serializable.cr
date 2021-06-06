class Hash
  annotation Field
  end

  # The `Hash::Serializable` module automatically generates methods for serialization when included.
  #
  # ### Example
  #
  # ```
  # require "hash_serializable"
  #
  # class Note
  #   include Hash::Serializable
  #
  #   property message : String = "DEFAULT"
  # end
  #
  # class Location
  #   include Hash::Serializable
  #
  #   @[Hash::Field(key: "lat")]
  #   property latitude : Float64
  #
  #   @[Hash::Field(key: "lon")]
  #   property longitude : Float64
  #
  #   property note : Note
  # end
  #
  # class House
  #   include Hash::Serializable
  #
  #   property address : String
  #   property location : Location?
  #   property note : Note
  # end
  #
  # arg = {
  #   "note" => {
  #     "message" => "Nice Address",
  #   },
  #   "address"  => "Crystal Road 1234",
  #   "location" => {
  #     "lat"  => 12.3,
  #     "lon"  => 34.5,
  #     "note" => {
  #       "message" => "hmmmm",
  #     },
  #   },
  # }
  # house = House.from_hash(arg)
  #
  # house.is_a?(House).should be_true
  # house.address.should eq "Crystal Road 1234"
  # house.location.is_a?(Location).should be_true
  # house.location.not_nil!.latitude.should eq 12.3
  # house.location.not_nil!.longitude.should eq 34.5
  # house.note.message.should eq "Nice Address"
  # house.location.not_nil!.note.message.should eq "hmmmm"
  # house.to_hash.should eq arg
  #
  # ### Usage
  #
  # Including `Hash::Serializable` will create `#to_hash` and `self.from_hash` methods
  # on the current class, and a constructor which takes a Hash. By default, `self.from_hash`
  # will deserialize a Hash into an instance of the object that it is passed to, according
  # to the definition of the class, and `#to_hash` will serialize the class into a Hash
  # containing the value of every instance variable, the keys being the instance variable
  # names.
  #
  # It will descend through a nested class structure, where variables in one class
  # point to objects that, in turn, have instance variables. It should also deal correctly
  # with type unions.
  #
  # To change how individual instance variables are parsed and serialized, the annotation
  # `Hash::Field` can be placed on the instance variable. Annotating property, getter, and
  # setter macros is also allowed.
  #
  # ```
  # require "hash_serializable"
  #
  # struct A
  #   include Hash::Serializable
  #
  #   @[Hash::Field(key: "my_key")]
  #   getter a : Int32?
  # end
  # ```
  #
  # `Hash::Field` properties:
  # * **ignore**: if `true` skip this field in serialization and deserialization (by default false)
  # * **ignore_serialize**: if `true` skip this field in serialization (by default false)
  # * **ignore_deserialize**: if `true` skip this field in deserialization (by default false)
  # * **key**: the value of the key in the json object (by default the name of the instance variable)
  # * **cast**: takes either a proc, or a method name; if proc, the hash value will be passed to the proc, and the return value will be used as the value of the instance variable; if method, the method will be called *on* the hash value, and the return value used for the instance variable value
  # * **presence**: if `true`, a `@{{key}}_present` instance variable will be generated when the key was present (even if it has a `null` value), `false` by default; this does not declare the `@{{key}}_present` variable for you, so you will be responsible for ensuring that a Bool variable is declared
  #
  # Deserialization respects default values of variables.
  #
  # ### Extensions: `Hash::Serializable::Strict` and `Hash::Serializable::Unmapped`
  #
  # If the `Hash::Serializable::Strict` module is included, unknown properties in the Hash
  # document will raise an exception. By default the unknown properties are silently ignored.
  #
  # If the `Hash::Serializable::Unmapped` module is included, unknown properties in the Hash
  # will be stored in a hash with an appropriate type signature. On serialization, any keys inside json_unmapped
  # will be serialized into the hash, as well.
  # ```
  # require "hash_serializable"
  #
  # struct A
  #   include Hash::Serializable
  #   include Hash::Serializable::Unmapped
  #   @a : Int32
  # end
  #
  # a = A.from_json(%({"a":1,"b":2})) # => A(@json_unmapped={"b" => 2_i64}, @a=1)
  # a.to_json                         # => {"a":1,"b":2}
  # ```
  #
  ### Casting
  #
  # *Hash::Serializable* can automatically convert values from one type to another. For example, if one has a *RequestParams* object that serialized the query parameters in an HTTP request, and one wanted to define a *user_id* field that was an integer, one might do something like this:
  #
  #   ```crystal
  #   struct RequestParams
  #     use Hash::Serializable
  #
  #     @[Hash::Field(cast: :to_i)]
  #     getter user_id : Int32
  #   end
  #
  #   params = RequestParams.new({"user_id" => "123"})
  #   pp params # >    #<RequestParams:0x7f2653e2f080 @user_id=123 >
  #   ```
  #
  #   One can also provide a proc to do the value conversion:
  #
  #   ```crystal
  #   struct MyObj
  #     use Hash::Serializable
  #
  #     @[Hash::Field(
  #       key: "number",
  #       cast: ->(x : String | Int::Signed | Int::Unsigned | Float::Primitive) do
  #         BigInt.new(x) ** 2
  #       end)]
  #     getter square : BigInt
  #   end
  #
  #   obj = MyObj.new({"number" => 12345678901234567890})
  #   pp obj # >    #<MyObj:0x7fc5adbe5e80 @square=152415787532388367501905199875019052100>
  #   ```
  #
  #   The library does not yet support having procs or methods which will cast back to the original type.
  #
  module Serializable
    VERSION = "0.1.0"

    macro included
      def self.new
        super
      end

      def self.new(hash : U) forall U
        new_from_hash(hash)
      end

      def self.new_from_hash(hash : U) forall U
        instance = allocate
        instance.initialize(hash)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      def self.from_hash(hash : U) forall U
        if Hash === hash
          self.new(hash.as(Hash))
        else
          raise Exception.new("Error: #{typeof(hash)} is an invalid type. #from_hash requires a Hash, but got a #{hash.class}.")
        end
      end

      macro inherited
        def self.new(hash : U) forall U
          new_from_hash(hash)
        end
      end
    end

    def initialize(hash : U) forall U
      # Normalize everything to string keys.
      hash = hash.transform_keys(&.to_s)

      {% begin %}
        {% # Generate a reference table for all of the properties that can be deserialized to

        properties = {} of Nil => Nil %}
        {% for ivar in @type.instance_vars %}
          {% ann = ivar.annotation(::Hash::Field) %}
          {% unless ann && (ann[:ignore] || ann[:ignore_deserialize]) %}
            {%
              properties[ivar.id] = {
                type:        ivar.type,
                key:         ((ann && ann[:key]) || ivar).id.stringify,
                has_default: ivar.has_default_value?,
                default:     ivar.default_value,
                nilable:     ivar.type.nilable?,
                root:        ann && ann[:root],
                cast:        ann && ann[:cast],
                presence:    ann && ann[:presence],
              }
            %}
          {% end %}
        {% end %}

        found = {} of String => Bool
        {% for name, value in properties %}
          if hash.has_key?({{ value[:key] }})
            found[{{ value[:key] }}] = true
            {%
              # If a cast is defined, attempt to convert values.
            %}
            {% if value[:cast] %}
              {% if value[:cast].is_a?(ProcLiteral) %}
                inner_val = {{ value[:cast] }}.call(hash[{{ value[:key] }}])
              {% else %}
                inner_val = hash[{{ value[:key] }}].{{ value[:cast].id }}
              {% end %}
              {% if value[:has_default] %}
                {{ name }}_val = inner_val.as?({{ value[:type] }}) || {{ value[:default] }}
              {% elsif value[:nilable] %}
                {{ name }}_val = inner_val.as?({{ value[:type] }})
              {% else %}
                {{ name }}_val = inner_val.as({{ value[:type] }})
              {% end %}
            {% elsif !value[:type].union_types.select { |ut| ut.class.methods.map(&.name.stringify).includes?("from_hash") }.empty? %}
              {{ name }}_val = {{ value[:type].union_types.select { |ut| ut.class.methods.map(&.name.stringify).includes?("from_hash") }.first }}.from_hash(hash[{{ value[:key] }}])
            {% else %}
              {% if value[:has_default] %}
                if hash[{{ value[:key] }}].is_a?({{ value[:type] }})
                  {{ name }}_val = hash[{{ value[:key] }}].as?({{ value[:type] }}) || {{ value[:default] }}
                else
                  {{ name }}_val = {{ value[:default] }}
                end
              {% else %}
              if hash[{{ value[:key] }}].is_a?({{ value[:type] }})
                {{ name }}_val = hash[{{ value[:key] }}].as({{ value[:type] }})
              end
              {% end %}
            {% end %}
          else
            {% if value[:has_default] %}
            {{ name }}_val = {{ value[:default] }}
            {% end %}
            found[{{ value[:key] }}] = false
          end

          {% if value[:nilable] %}
            {% if value[:has_default] %}
              @{{ name }} = found[{{ value[:key] }}] && {{ name }}_val.as?({{ value[:type] }}) ? {{ name }}_val : {{ value[:default] }}
            {% else %}
              @{{ name }} = {{ name }}_val.as?({{ value[:type] }})
            {% end %}
          {% elsif value[:has_default] %}
            if !found[{{ value[:key] }}]
              @{{ name }} = {{ value[:default] }}
            else
              if {{ name }}_val.nil?
                {{ value[:default] }}
              else
                @{{ name }} = {{ name }}_val.as({{ value[:type] }})
              end
            end
          {% else %}
            if {{ name }}_val.nil?
              raise ::Hash::SerializableError.new("Value for key {{name}} is not present, and this field is not nilable and has no default.", self.class.to_s)
            else
              @{{ name }} = {{ name }}_val.as({{ value[:type] }})
            end
          {% end %}

          {% if value[:presence] %}
            @{{name}}_present = found[{{ value[:key] }}]
          {% end %}
        {% end %}

        # Handle the unknown keys.
        {% begin %}
          {% types = {} of TypeNode => Bool %}
          {% for ivar in @type.instance_vars %}
            {%
              ann = ivar.annotation(::Hash::Field)
              unless ann && (ann[:ignore] || ann[:ignore_deserialize])
                types[ivar.type] = true
              end
            %}
          {% end %}

          (hash.keys - found.keys).each {|key| on_unknown_hash_attribute(key, hash[key])}
        {% end %}

      {% end %}
    end

    protected def after_initialize
    end

    protected def on_unknown_hash_attribute(key, value)
    end

    def to_hash
      {% begin %}
        {%
          # This monsterous code walks the object structure, finding all of the
          # instance variables in all of the nested objects in order to determine
          # what the type signature must be for the generated Hash.
          # Walking an arbitrarily nested structure when one can't define any sort
          # of method or proc, can't use while loops, can't use next or break, and
          # can't delete elements from an array, among other restrictions, is tricky.
          tstack = [] of Nil # tstack is the type stack
          ostack = [] of Nil # ostack is the object stack
          estack = [] of Nil # estack is the element stack - actually array indexes to be used with the ostack

          tstack << [] of Nil
          ostack << @type.instance_vars
          estack << (0..(@type.instance_vars.size - 1)).to_a

          (1..99999).each do # while loops aren't allowed, so we just pick an arbitrary number that is probably big enough
            if !ostack.empty? # These lines implement a really inefficient array pop.
              o = ostack.last
              oo = ostack
              ostack = [] of Nil
              (0..(oo.size - 2)).each do |idx|
                ostack << oo[idx]
              end

              keys = estack.last
              oe = estack
              estack = [] of Nil
              (0..(oe.size - 2)).each do |idx|
                estack << oe[idx]
              end

              if !keys.nil? && !keys.empty?
                (1..99999).each do
                  if !keys.nil? && !keys.empty?
                    e = keys.first
                    ok = keys
                    keys = [] of Nil
                    (1..(ok.size - 1)).each do |idx|
                      keys << ok[idx]
                    end
                    if o[e].type.union_types.reject { |typ| typ == Nil }.first.class.methods.map(&.name.stringify).includes?("from_hash")
                      oe = o[e].type.union_types.reject { |typ| typ == Nil }.first
                      tstack << [] of Nil
                      ostack << o
                      estack << keys
                      ostack << oe.instance_vars
                      estack << (0..(oe.instance_vars.size - 1)).to_a
                      keys = [] of Nil
                    else
                      if o[e].type.nilable?
                        tstack.last << "#{o[e].type} | Nil"
                      else
                        tstack.last << o[e].type
                      end

                      if keys.empty? && tstack.size > 1
                        ot = tstack
                        top = tstack.last
                        tstack = [] of Nil
                        (0..(ot.size - 2)).each do |idx|
                          tstack << ot[idx]
                        end
                        tstack.last << top
                        tstack.last << Nil
                      end
                    end
                  end
                end
              elsif tstack.size > 1
                ot = tstack
                top = tstack.last
                tstack = [] of Nil
                (0..(ot.size - 2)).each do |idx|
                  tstack << ot[idx]
                end
                tstack.last << top
              end
            end
          end

          types = {} of TypeNode => Bool
          tstack.first.each do |type|
            types[type] = true
          end

          type_string = types.keys.map do |m|
            m.id
          end.join(" | ").id.
          gsub(/\s*,\s*/, " | ").
          gsub(/\[/, "Hash(String, ").gsub(/]/, ")").gsub(/Hash\(String\s*\|/, "Hash(String, ").id
        %}

        h = {} of String => ({{ type_string }})
        {% for ivar in @type.instance_vars %}
          {%
            ann = ivar.annotation(::Hash::Field)
            key = ((ann && ann[:key]) || ivar).id.stringify
          %}
          {% unless ann && (ann[:ignore] || ann[:ignore_serialize]) %}
            {{ ivar.name }}_ivar = @{{ ivar.name }}
            if {{ ivar.name }}_ivar.responds_to?(:to_hash)
              h[{{ key }}] = {{ ivar.name }}_ivar.to_hash
            else
              h[{{ key }}] = {{ ivar.name }}_ivar
            end
          {% end %}
        {% end %}
        {% if @type.instance_vars.select {|iv| iv.name.stringify == "hash_unmapped"}.empty? %}
          h
        {% else %}
          h.merge(@hash_unmapped)
        {% end %}
      {% end %}
    end

    module Strict
      protected def on_unknown_hash_attribute(key, value)
        raise ::Hash::SerializableError.new("Unknown Hash Key: #{key}", self.class.to_s)
      end
    end

    module Unmapped(K)
      @[Hash::Field(ignore: true)]
      property hash_unmapped = {} of String => K

      protected def on_unknown_hash_attribute(key, value)
        hash_unmapped[key] = value.as?(K)
      end
    end
  end

  class SerializableError < Exception
    getter klass : String
    getter attribute : String?

    def initialize(
      message : String?,
      @klass : String,
      @attribute : String? = nil
    )
      super("#{message}\n  parsing #{klass}#{if (attribute = @attribute)
                                               {"##{attribute}"}
                                             end}")
    end
  end
end
