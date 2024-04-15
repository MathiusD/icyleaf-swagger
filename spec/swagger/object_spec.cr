require "../spec_helper"

module Example
end

struct Example::Author
  property name

  def initialize(@name : String)
  end
end

enum VCS
  GIT
  SUBVERSION
  MERCURIAL
  FOSSIL
end

struct Example::SelfRef
  property refs

  def initialize(@refs : Array(Example::SelfRef) | Nil)
  end
end

struct Project
  property id, name, description, vcs, open_source, author, contributors

  def initialize(
    @id : Int32, @name : String, @vcs : VCS, @open_source : Bool,
    @author : Example::Author, @description : String? = nil,
    @contributors : Array(String) = [] of String
  )
  end
end


struct Example::YamlObject
  @[YAML::Field(key: "_name")]
  property name : String

  def initialize(@name)
  end
end

struct Example::JsonObject
  @[JSON::Field(key: "Name")]
  property name : String

  def initialize(@name)
  end
end

struct Example::JsonAndYamlObject
  @[JSON::Field(key: "Name")]
  @[YAML::Field(key: "_name")]
  property name : String

  def initialize(@name)
  end
end

describe Swagger::Object do
  describe "#new" do
    it "should works" do
      properties = [
        Swagger::Property.new("id", "integer", "int32", example: 1),
        Swagger::Property.new("nickname", example: "icyleaf wang"),
        Swagger::Property.new("username", example: "icyleaf"),
        Swagger::Property.new("email", example: "icyleaf.cn@gmail.com"),
        Swagger::Property.new("bio", "Personal bio"),
      ]
      raw = Swagger::Object.new("User", "object", properties)
      raw.name.should eq "User"
      raw.type.should eq "object"
      raw.properties.should_not be_nil
      raw.properties.try &.size.should eq 5
    end

    it "should supports the type array with items as an object" do
      raw = Swagger::Object.new(
        "CommentList",
        "array",
        items: Swagger::Object.new(
          "Comment",
          "object",
        )
      )
      raw.type.should eq("array")
      raw.properties.should be_nil
      raw.items.class.should eq(Swagger::Object)
    end

    it "should supports the type array with items as a ref" do
      raw = Swagger::Object.new(
        "CommentList",
        "array",
        items: "Comment",
      )
      raw.type.should eq("array")
      raw.properties.should be_nil
      raw.items.should eq("Comment")
    end

    it "should generate schema of object with ref from object instance" do
      author = Example::Author.new("icyleaf")
      raw = Swagger::Object.create_from_instance(
        Project.new(1,
          "swagger", VCS::GIT, true,
          author,
          "Swagger contains a OpenAPI / Swagger universal documentation generator and HTTP server handler.",
          ["j8r"]
          ),
        refs: {
          "exampleAuthor" => Swagger::Object.create_from_instance(
            author
          ),
        },
      )
      raw.name.should eq "project"
      raw.type.should eq "object"
      raw.items.should be nil
      raw.properties.should be_a(Array(Swagger::Property))
      raw.properties.not_nil!.size.should eq 7
      raw.properties.not_nil![0].should eq Swagger::Property.new("id", "integer", "int32", example: 1, required: true)
      raw.properties.not_nil![1].should eq Swagger::Property.new("name", example: "swagger", required: true)
      raw.properties.not_nil![2].should eq Swagger::Property.new(
        "vcs", "object", example: "GIT", required: true, enum_values: [
          "GIT", "SUBVERSION", "MERCURIAL", "FOSSIL",
        ]
      )
      raw.properties.not_nil![3].should eq Swagger::Property.new("open_source", "boolean", example: true, required: true)
      raw.properties.not_nil![4].should eq Swagger::Property.new("author", "object", required: true, ref: "exampleAuthor")
      raw.properties.not_nil![5].should eq Swagger::Property.new(
        "description",
        example: "Swagger contains a OpenAPI / Swagger universal documentation generator and HTTP server handler.",
        required: false
      )
      raw.properties.not_nil![6].should be_a(Swagger::Property)
      raw.properties.not_nil![6].name.should eq "contributors"
      raw.properties.not_nil![6].required.should eq true
      raw.properties.not_nil![6].items.should be_a(Swagger::Object)
      raw.properties.not_nil![6].items.not_nil!.as(Swagger::Object).name.should eq "itemOfstring"
      raw.properties.not_nil![6].items.not_nil!.as(Swagger::Object).type.should eq "string"
      raw.properties.not_nil![6].items.not_nil!.as(Swagger::Object).properties.should be_nil
      raw.properties.not_nil![6].items.not_nil!.as(Swagger::Object).items.should be_nil
    end

    it "should generate schema of object with self ref" do
      raw = Swagger::Object.create_from_instance(
        Example::SelfRef.new(
          [
            Example::SelfRef.new(nil),
          ]
        )
      )
      raw.name.should eq "exampleSelfRef"
      raw.type.should eq "object"
      raw.items.should be nil
      raw.properties.should eq [
        Swagger::Property.new("refs", "array", required: false, items: "exampleSelfRef"),
      ]
    end

    it "shouldn't generate schema of object without ref from object instance" do
      expect_raises(Swagger::Object::RefResolutionException, "No refs provided !") do
        Swagger::Object.create_from_instance(
          Project.new(1,
            "swagger", VCS::GIT, true,
            Example::Author.new("icyleaf"),
            "Swagger contains a OpenAPI / Swagger universal documentation generator and HTTP server handler.")
        )
      end
    end

    it "shouldn't generate schema of object without correct ref from object instance" do
      expect_raises(Swagger::Object::RefResolutionException, "Ref for Example::Author not found (Searched for followed name : exampleAuthor)") do
        Swagger::Object.create_from_instance(
          Project.new(1,
            "swagger", VCS::GIT, true,
            Example::Author.new("icyleaf"),
            "Swagger contains a OpenAPI / Swagger universal documentation generator and HTTP server handler."),
          refs: {"SomeStringAlias" => "string"},
        )
      end
    end

    it "should generate schema of object with name of json annotation" do
      raw = Swagger::Object.create_from_instance(
        Example::JsonObject.new(
          "Example"
        )
      )
      raw.name.should eq "exampleJsonObject"
      raw.type.should eq "object"
      raw.items.should be nil
      raw.properties.should eq [
        Swagger::Property.new("Name", "string", required: true, example: "Example"),
      ]
    end

    it "should generate schema of object with name of yaml annotation" do
      raw = Swagger::Object.create_from_instance(
        Example::YamlObject.new(
          "Example"
        )
      )
      raw.name.should eq "exampleYamlObject"
      raw.type.should eq "object"
      raw.items.should be nil
      raw.properties.should eq [
        Swagger::Property.new("_name", "string", required: true, example: "Example"),
      ]
    end

    it "should generate schema of object with name of json annotation if present even if yaml annotation are present also" do
      raw = Swagger::Object.create_from_instance(
        Example::JsonAndYamlObject.new(
          "Example"
        )
      )
      raw.name.should eq "exampleJsonAndYamlObject"
      raw.type.should eq "object"
      raw.items.should be nil
      raw.properties.should eq [
        Swagger::Property.new("Name", "string", required: true, example: "Example"),
      ]
    end
  end
end
