module Swagger::Object
  struct RequestBody
    include JSON::Serializable

    getter description : String? = nil
    getter content : Hash(String, MediaType)? = nil
    getter required : Bool = false

    @[JSON::Field(key: "$ref")]
    getter ref : String? = nil

    def initialize(@description : String? = nil, @content : Hash(String, MediaType)? = nil,
                   @required : Bool = false, @ref : String? = nil)
    end
  end
end
