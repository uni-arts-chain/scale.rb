module Scale
  module Types
    class MetadataV14
      include Base
      attr_accessor :call_index, :event_index

      def initialize(value)
        @call_index = {}
        @event_index = {}
        super(value)
      end

      def self.decode(scale_bytes)
        portables = Scale::Types.get("PortableRegistry").decode(scale_bytes)
        portable_hash = portables.to_human
        modules = Scale::Types.get("Vec<MetadataV14Module>").decode(scale_bytes).value
        call_module_index = 0
        event_module_index = 0
        value = {
          magicNumber: 1_635_018_093,
          metadata: {
            version: 12,
            modules: modules.map(&:value)
          }
        }

        result = MetadataV14.new(value)
        modules.map(&:value).each do |m|
          module_index = m[:index]
          if m[:calls]
            portable_hash[module_index][:def]
            m[:calls].each_with_index do |call, index|
              portable_hash[modifier_enum]
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
        result
      end
    end

    class MetadataV14ModuleStorage
      include Base
      def self.decode(scale_bytes)
        prefix = String.decode(scale_bytes).value
        items = Scale::Types.get("Vec<MetadataV14ModuleStorageEntry>").decode(scale_bytes).value.map(&:value)
        result = {
          prefix: prefix,
          items: items
        }

        MetadataV14ModuleStorage.new(result)
      end
    end

    class MetadataV14ModuleStorageEntry
      include Base
      def self.decode(scale_bytes)
        name = String.decode(scale_bytes).value
        modifier_enum = {
          "type" => "enum",
          "value_list" => ["Optional", "Default"]
        }
        modifier = Scale::Types.get(modifier_enum).decode(scale_bytes).value
        result = {
          name: name,
          modifier: modifier
        }

        storage_function_type_enum = {
          "type" => "enum",
          "value_list" => %w[PlainType Map]
        }
        storage_function_type = Scale::Types.get(storage_function_type_enum).decode(scale_bytes).value
        if storage_function_type == "PlainType"
          result[:type] = {
            Plain: Scale::Types.get("SiLookupTypeId").decode(scale_bytes).value
          }
        elsif storage_function_type == "Map"
          result[:type] = {
            Map: {
              hasher: Scale::Types.get("Vec<StorageHasher>").decode(scale_bytes).value,
              key: Scale::Types.get("SiLookupTypeId").decode(scale_bytes).value,
              value: Scale::Types.get("SiLookupTypeId").decode(scale_bytes).value
            }
          }
        end

        result[:fallback] = Hex.decode(scale_bytes).value
        result[:documentation] = Scale::Types.get("Vec<String>").decode(scale_bytes).value.map(&:value)

        MetadataV14ModuleStorageEntry.new(result)
      end
    end

    class MetadataV14Module
      include Base
      def self.decode(scale_bytes)
        name = String.decode(scale_bytes).value
        result = {
          name: name
        }

        has_storage = Bool.decode(scale_bytes).value
        if has_storage
          storage = MetadataV14ModuleStorage.decode(scale_bytes).value
          result[:storage] = storage
          result[:prefix] = storage[:prefix]
        end

        has_calls = Bool.decode(scale_bytes).value
        if has_calls
          call = Scale::Types.get("PalletCallMetadataV14").decode(scale_bytes).value
          result[:calls] = call
        end

        has_events = Bool.decode(scale_bytes).value
        if has_events
          event = Scale::Types.get("PalletEventMetadataV14").decode(scale_bytes).value
          result[:events] = {:type => event}
        end

        result[:constants] = Scale::Types.get("Vec<PalletConstantMetadataV14>").decode(scale_bytes).value.map(&:value)

        has_errors = Bool.decode(scale_bytes).value
        if has_errors
          error = Scale::Types.get("PalletErrorMetadataV14").decode(scale_bytes).value
          result[:errors] = error
        end
        
        result[:index] = U8.decode(scale_bytes).value
        MetadataV14Module.new(result)
      end
    end
  end
end
