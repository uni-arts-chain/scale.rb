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
    scale_bytes = Scale::Bytes.new(hex)
    portables = Scale::Types.get("PortableRegistry").decode(scale_bytes)
    portables_to_human = portables.to_human
    #.{:id=>0, :type=>{:path=>["sp_core", "crypto", "AccountId32"], :params=>[], :def=>{:fields=>[{:name=>nil, :type=>1, :typeName=>"[u8; 32]", :docs=>[]}]}, :docs=>[]}}
    portables_to_hash = {}
    portables_to_human.each do |portable|
      portables_to_hash[portable[:id]] = portable
    end
   
    modules = Scale::Types.get("Vec<MetadataV14Module>").decode(scale_bytes).value
    result = Scale::Types.get("MetadataV14").new(modules)
    call_module_index = 0
    event_module_index = 0

    modules.map(&:value).each do |m|
      if m[:calls]
        puts 1111111111
        variants = portables_to_hash[m[:calls]["type"].value][:type][:def][:Variant][:variants]
        raise "call value not variant" if variants.nil?
        puts variants.inspect
        m[:calls] = variants
        m[:calls].each_with_index do |call, index|
          call[:lookup] = "%02x%02x" % [m[:index], index]
          result.call_index[call[:lookup]] = [m, call]
        end
      end


      if m[:events]
        m[:events].each_with_index do |event, index|
          event[:lookup] = "%02x%02x" % [module_index, index]
          result.event_index[event[:lookup]] = [m, event]
        end
      end
    end
    expect(portables).to eql(nil)
  end

end
