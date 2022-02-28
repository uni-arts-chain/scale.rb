require "scale"
require "json"
require "pathname"
require "open-uri"

ROOT = Pathname.new File.expand_path("../../", __FILE__)
Scale::TypeRegistry.instance.load(spec_name: "kusama")
Scale::TypeRegistry.instance.spec_version = 1054

def get_metadata_hex(version)
  File.open(File.join(ROOT, "spec", "metadata", "v#{version}", "hex")).read.strip
end

def get_metadata(version)
  content = File.open(File.join(ROOT, "spec", "metadata", "v#{version}", "expect.json")).read.strip
  JSON.parse(content, symbolize_names: true)
end

describe Scale::Types::Metadata do
  it "can decode v0 hex data" do
    hex = get_metadata_hex(0)
    scale_bytes = Scale::Bytes.new(hex)
    metadata = Scale::Types::Metadata.decode(scale_bytes)
    v = metadata.value.value[:metadata]

    expected = get_metadata(0)

    expect(metadata.version).to eql(0)
    expect(v[:outerEvent][:events].length).to eql(expected[:outerEvent][:events].length)
    expect(v[:modules].length).to eql(expected[:modules].length)
    expect(v[:outerDispatch][:calls].length).to eql(expected[:outerDispatch][:calls].length)

    expect(v.to_json).to eql(expected.to_json)
  end

  it "get scale info" do
    hex = get_metadata_hex(14)
    puts 22222
    puts Scale::Types.get("SiLookupTypeId").inspect
    scale_bytes = Scale::Bytes.new(hex)
    metadata = Scale::Types::Metadata.decode(scale_bytes)
    expect(metadata).to eql(nil)
  end

end
