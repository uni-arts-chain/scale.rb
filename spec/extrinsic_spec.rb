require "scale"
require 'pathname'

ROOT = Pathname.new File.expand_path("../../", __FILE__)

module Scale::Types
  describe Extrinsic do
    before(:all) {
      Scale::TypeRegistry.instance.load(spec_name: "kusama")
      Scale::TypeRegistry.instance.spec_version = 1045
      Scale::TypeRegistry.instance.add_custom_type({"aaaa" => "U32"})
      hex = File.open(File.join(ROOT, "spec", "metadata", "v14", "hex")).read.strip
      scale_bytes = Scale::Bytes.new(hex)
      metadata = Scale::Types::Metadata.decode scale_bytes
      Scale::TypeRegistry.instance.metadata = metadata
    }

    it "can encode transfer payload" do

      puts "---------"
      Scale::Types.instance.add_custom_type({"aaaa" => "U32"})
      puts Scale::Types.instance.custom_type

      value = {
        call_module: "balances",
        call_function: "transfer",
        call_args: {
            dest: "0x586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409",
            value: 1_000_000_000_000
        }
      }
      call = GenericCall.new(value)
      extrinsic = Extrinsic.new({call: call})
      expect(call.encode).to eql("0600ff586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409070010a5d4e8")
      expect(extrinsic.encode).to eql("a8040600ff586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409070010a5d4e8")
    end

    # it "can encode to transfer payload 2" do
      # client = SubstrateClient.new("wss://cc3-5.kusama.network/")
      # client.init

      # call_params = { dest: "0x586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409", value: 1_000_000_000_000 }
      # payload = client.compose_call("balances", "transfer", call_params)
      # expect(payload).to eql("0xa8040400ff586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409070010a5d4e8")
    # end
  end

end
