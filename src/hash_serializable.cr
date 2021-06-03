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
  # class Location
  #   include Hash::Serializable
  #
  #   @[Hash::Field(key: "lat")]
  #   property latitude : Float64
  #
  #   @[Hash::Field(key: "lon")]
  #   property longitude : Float64
  # end
  module Serializable
    VERSION = "0.1.0"

    macro included
      def self.new
        super
      end

      def self.new(hash : Hash(K,V)) forall K,V
        new_from_hash(hash)
      end

      def self.new_from_hash(hash : Hash(K,V)) forall K,V
        instance = allocate
        instance.initialize(hash)
        GC.add_finalizer(instance) if instance.responds_to?(:finalize)
        instance
      end

      def self.from_hash(hash : Hash(K, V)) forall K, V
        self.new(hash)
      end

      # This is a honeypot. It exists 
      def self.from_hash(hash : U) forall U
        raise Exception.new("Error: #{typeof(hash)} is an invalid type. #from_hash requires a Hash.")
      end

      macro inherited
        def self.new(hash : Hash(K,V)) forall K,V
          new_from_hash(hash)
        end
      end
    end

    def initialize(hash : Hash(K, V)) forall K, V
      # Normalize everything to string keys.
      hash = hash.transform_keys {|k| k.to_s}

      {% begin %}
        {%
          # Generate a reference table for all of the properties that can be deserialized to
          properties = {} of Nil => Nil
        %}
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
                converter:   ann && ann[:converter],
                presence:    ann && ann[:presence],
              }
            %}
          {% end %}
        {% end %}

        found = {} of String => Bool
        {% for name, value in properties %}
        {% puts "#{name} == #{value}\n#{value[:type].union_types.map {|t| t.class.methods.map {|m| m.name.id}}}" %}
        {% puts "#{value[:type].union_types.select {|ut| ut.class.methods.map {|m| m.name.stringify}.includes?("from_hash")}}" %}
          if hash.has_key?({{ value[:key] }})
            found[{{ value[:key] }}] = true
            {% if value[:converter] %}
              {{ name }}_val = {{ value[:converter] }}(hash[{{ value[:key] }}])
            {% elsif !value[:type].union_types.select {|ut| ut.class.methods.map {|m| m.name.stringify}.includes?("from_hash")}.empty? %}
              {{ name }}_val = {{ value[:type].union_types.select {|ut| ut.class.methods.map {|m| m.name.stringify}.includes?("from_hash")}.first }}.from_hash(hash[{{ value[:key] }}])
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

          {{ name }}_val = {{ name }}_val.as({{ value[:type] }})
          {% if value[:nillable] %}
            {% if value[:has_default] %}
              @{{ name }} = found[{{ value[:key] }}]  ? val : {{ value[:default] }}
            {% else %}
              @{{ name }} = {{ name }}_val
            {% end %}
          {% elsif value[:has_default] %}
            if !found[{{ value[:key] }}]
              @{{ name }} = {{ value[:default] }}
            else
              @{{ name }} = {{ name }}_val
            end
          {% else %}
            @{{ name }} = {{ name }}_val
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
          tstack = [] of Nil
          ostack = [] of Nil
          estack = [] of Nil
        
          tstack << [] of Nil
          ostack << @type.instance_vars
          estack << (0..(@type.instance_vars.size - 1)).to_a
        
          (1..99999).each do
            if !ostack.empty?
        
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
                    if o[e].type.union_types.reject {|typ| typ == Nil}.first.class.methods.map {|m| m.name.stringify}.includes?("from_hash")
                      oe = o[e].type.union_types.reject {|typ| typ == Nil}.first
                      tstack << [] of Nil
                      ostack << o
                      estack << keys
                      ostack << oe.instance_vars
                      estack << (0..(oe.instance_vars.size - 1)).to_a
                      keys = [] of Nil
                    else
                      tstack.last << o[e].type
        
                      if keys.empty? && tstack.size > 1
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

          puts "\n\n\n**********\n#{tstack}"
          types = {} of TypeNode => Bool
          tstack.first.each do |type|
            types[type] = true
          end
          puts "==========\n#{types}"
        %}

        # {{ types }}
        h = {} of String => {{ types.keys.map {|m| m.id}.join(" | ").id }}
        {% for ivar in @type.instance_vars %}
          {%
            ann = ivar.annotation(::Hash::Field)
            key = ((ann && ann[:key]) || ivar).id.stringify
          %}
          {% unless ann && (ann[:ignore] || ann[:ignore_serialize]) %}
            ivar_name = @{{ ivar.name }}
            if ivar_name.responds_to?(:to_hash)
              h[{{ key }}] = ivar_name.to_hash
            else
              h[{{ key }}] = ivar_name
            end
          {% end %}
        {% end %}
        h
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
        #hash_unmapped[key] = value
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
