class Hash
  annotation Field
  end

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

      macro inherited
        def self.new(hash : Hash(K,V)) forall K,V
          new_from_hash(hash)
        end
      end
    end

    def initialize(hash : Hash(K, V)) forall K, V
      {% begin %}
        {% properties = {} of Nil => Nil %}
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

        # Write code to extract hash key/values to ivars.
        found = {} of String => Bool
        {% for name, value in properties %}
          if hash.has_key?({{ value[:key] }})
            found[{{ value[:key] }}] = true
            {% if value[:converter] %}
            val = {{ value[:converter] }}(hash[{{ value[:key] }}])
            {% else %}
            val = hash[{{ value[:key] }}]
            {% end %}
          else
            found[{{ value[:key] }}] = false
          end

          {% if value[:nillable] %}
            {% if value[:has_default] %}
              @{{ name }} = found[{{ value[:key] }}] ? val : {{ value[:default] }}
            {% else %}
              @{{ name }} = val
            {% end %}
          {% elsif value[:has_default] %}
            if !found[{{ value[:key] }}]
              @{{ name }} = {{ value[:default] }}
            else
              @{{ name }} = val.as({{ value[:type] }})
            end
          {% else %}
            @{{ name }} = val.as({{ value[:type] }})
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
              unless ann && ann[:ignore]
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
        {% types = {} of TypeNode => Bool %}
        {% for ivar in @type.instance_vars %}
        {%
        ann = ivar.annotation(::Hash::Field)
        unless ann && ann[:ignore]
          types[ivar.type] = true
        end
      %}         
      {% end %}
        h = {} of String => {{ types.keys.select { |k| k.resolve? }.map { |k| k.resolve }.join(" | ").id }}
        {% for ivar in @type.instance_vars %}
          {%
            ann = ivar.annotation(::Hash::Field)
            key = ((ann && ann[:key]) || ivar).id.stringify
          %}
          {% unless ann && ann[:ignore] %}
            h[{{ key }}] = @{{ ivar.name }}
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
          hash_unmapped[key] = value
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
