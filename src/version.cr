class Hash
  module Serializable
    {% begin %}
    VERSION = {{ read_file("#{__DIR__}/../VERSION").chomp }}
    {% end %}
  end
end
