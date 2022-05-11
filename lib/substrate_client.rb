require "faye/websocket"
require "eventmachine"

def ws_request(ws_url, payload, http_url)
  result = nil

  EM.run do
    ws = Faye::WebSocket::Client.new(ws_url)

    ws.on :open do |event|
      ws.send(payload.to_json)
    end

    ws.on :message do |event|
      if event.data.include?("jsonrpc")
        result = JSON.parse event.data
        ws.close(3001, "data received")
        EM.stop
      end
    end

    ws.on :close do |event|
      ws = nil
    end

    ws.on :error do |event|
      EM.stop
    end
  end

  result = http_request(http_url, payload) if result.nil? && http_url.present?
  result
rescue
  return nil if http_url.blank?
  http_request(http_url, payload)
end

def http_request(http_url, payload)
  r = RestClient.post(http_url, payload.to_json, { content_type: :json, accept: :json })
  JSON.parse(r.body)
rescue => ex
  { "error": ex.message }
end

class SubstrateClient
  class WebsocketError < StandardError; end
  class RpcError < StandardError; end
  class RpcTimeout < StandardError; end

  attr_reader :metadata
  attr_reader :spec_name, :spec_version

  def initialize(ws_url, http_url = nil)
    @ws_url = ws_url
    @http_url = http_url
    @request_id = 1
    @metadata_cache = {}
    init_types_and_metadata
  end

  def request(method, params)
    payload = {
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params,
      "id" => @request_id
    }

    data = http_request(@http_url, payload)
    if data.nil?
      raise @ws_url, payload.inspect, "url:#{@ws_url}, payload: #{payload.inspect}, data: #{data.inspect}"
    elsif data["error"]
      raise RpcError, data["error"]
    else
      data["result"]
    end
  end

  def init_types_and_metadata(block_hash=nil)
    runtime_version = self.state_getRuntimeVersion(block_hash)
    spec_name = runtime_version["specName"].downcase
    spec_version = runtime_version["specVersion"]

    registry = Scale::TypeRegistry.instance

    # load types
    if registry.types == nil
      registry.load(spec_name: spec_name)
    end
    registry.spec_version = spec_version

    # set current metadata
    metadata = @metadata_cache[spec_version]
    if metadata.nil?
      hex = self.state_getMetadata(block_hash)
      metadata = Scale::Types::Metadata.decode(Scale::Bytes.new(hex))
      @metadata_cache[spec_version] = metadata
    end

    @metadata = metadata
    registry.metadata = metadata

    true
  end

  def get_metadata_from_cache(spec_version)

  end

  def invoke(method, *params)
    request(method, params)
  end

  # ################################################
  # origin rpc methods
  # ################################################
  def method_missing(method, *args)
    invoke method, *args
  end

  # ################################################
  # custom methods based on origin rpc methods
  # ################################################
  def methods
    invoke("rpc_methods")["methods"]
  end

  def get_block_number(block_hash)
    header = self.chain_getHeader(block_hash)
    header["number"].to_i(16)
  end

  def get_metadata(block_hash=nil)
    self.init_types_and_metadata(block_hash)
    @metadata
  end

  def get_block(block_hash=nil)
    self.init_types_and_metadata(block_hash)
    block = self.chain_getBlock(block_hash)
    SubstrateClient::Helper.decode_block(block)
  rescue => ex
    puts ex.message
    puts ex.backtrace.join("\n\t")
  end

  def get_block_events(block_hash=nil)
    self.init_types_and_metadata(block_hash)

    storage_key =  "0x26aa394eea5630e07c48ae0c9558cef780d41e5e16056765bc8461851072c9d7"
    events_data = state_getStorage storage_key, block_hash

    scale_bytes = Scale::Bytes.new(events_data)
    decoded = Scale::Types.get("Vec<EventRecord>").decode(scale_bytes).to_human
    [events_data, decoded]
  end

  def get_storage(module_name, storage_name, params = nil, block_hash = nil)
    self.init_types_and_metadata(block_hash)

    storage_key, return_type, storage_item = SubstrateClient::Helper.generate_storage_key_from_metadata(@metadata, module_name, storage_name, params)

    data = self.state_getStorage(storage_key, block_hash)

    if data.nil?
      return if storage_item[:modifier] == "Optional"

      data = storage_item[:fallback]
    end

    bytes = Scale::Bytes.new(data)
    type = Scale::Types.get(return_type)
    type.decode(bytes)
  end

  def generate_storage_key(module_name, storage_name, params = nil, block_hash = nil)
    self.init_types_and_metadata(block_hash)
    SubstrateClient::Helper.generate_storage_key_from_metadata(@metadata, module_name, storage_name, params)
  end

  # compose_call "Balances", "Transfer", { dest: "0x586cb27c291c813ce74e86a60dad270609abf2fc8bee107e44a80ac00225c409", value: 1_000_000_000_000 }
  def compose_call(module_name, call_name, params, block_hash=nil)
    self.init_types_and_metadata(block_hash)
    SubstrateClient::Helper.compose_call_from_metadata(@metadata, module_name, call_name, params)
  end

  def generate_storage_hash_from_data(storage_hex_data)
    "0x" + Crypto.blake2_256(Scale::Bytes.new(storage_hex_data).bytes)
  end

end
