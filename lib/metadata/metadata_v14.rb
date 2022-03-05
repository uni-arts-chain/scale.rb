
require_relative "./portable.rb"
module Scale
  module Types
    class MetadataV14
      include Base
      attr_accessor :call_index, :event_index, :extrinsic, :portables_to_hash, :all_portable_hash

      def initialize(value)
        @call_index = {}
        @event_index = {}
        @extrinsic = nil
        @all_portable_hash = {}
        @portables_to_hash = {}
        super(value)
      end

      def self.decode(scale_bytes)
        portables = Scale::Types.get("PortableRegistry").decode(scale_bytes)
        portables_to_human = portables.to_human
        portable = Portable.new
        portable.compact_all_types portables_to_human
        all_portable_hash = portable.all_portable_hash
        puts "-----"
        puts all_portable_hash.inspect
       
        portables_to_hash = {}
        portables_to_human.each do |portable|
          portables_to_hash[portable[:id]] = all_portable_hash
        end
        puts "----1111----"
        puts portables_to_hash.inspect
      
        modules = Scale::Types.get("Vec<MetadataV14Module>").decode(scale_bytes).value
      
        value = {
          magicNumber: 1_635_018_093,
          metadata: {
            version: 14,
            modules: modules.map(&:value)
          }
        }

        result = MetadataV14.new(value)
        call_module_index = 0
        event_module_index = 0

        origin_callers = []
        modules.map(&:value).each do |m|
          origin_callers << {name: m[:name], index: m[:index]}
          if m[:calls]
            calls = []
            variants = portables_to_hash[m[:calls][:type].value][:type][:def][:Variant][:variants]
            raise "call value not variant" if variants.nil?

            variants.each do |variant|
              call = {name: variant[:name], docs: variant[:docs], args: []}
              variant[:fields].each do |field|
                call[:args] << {name: field[:name], type: all_portable_hash[field[:type]]}
              end
              calls << call
            end
            m[:calls] = calls
            m[:calls].each_with_index do |call, index|
              m[:calls][index][:lookup] = "%02x%02x" % [m[:index], index]
              result.call_index[call[:lookup]] = [m, call]
            end
          end


          if m[:events]
            calls = []
            variants = portables_to_hash[m[:events][:type].value][:type][:def][:Variant][:variants]
            raise "call value not variant" if variants.nil?

            variants.each do |variant|
              call = {name: variant[:name], docs: variant[:docs], args: []}
              variant[:fields].each do |field|
                call[:args] << {name: field[:name], type: all_portable_hash[field[:type]]}
              end
              calls << call
            end
            m[:events] = calls
            m[:events].each_with_index do |event, index|
              m[:events][index][:lookup] = "%02x%02x" % [m[:index], index]
              result.call_index[event[:lookup]] = [m, event]
            end
          end

          if m[:errors]
            calls = []
            variants = portables_to_hash[m[:errors][:type].value][:type][:def][:Variant][:variants]
            raise "call value not variant" if variants.nil?

            variants.each do |variant|
              call = {name: variant[:name], docs: variant[:docs], args: []}
              calls << call
            end
            m[:errors] = calls
            m[:errors].each_with_index do |error, index|
              m[:errors][index][:lookup] = "%02x%02x" % [m[:index], index]
              result.call_index[error[:lookup]] = [m, error]
            end
          end


          if m[:constants]
            m[:constants].each_with_index do |constant, index|
              variant = all_portable_hash[constant.type.value.to_i]
              raise "#{constant.type.value} constant value not variant" if variant.nil?
              mc = Scale::Types.get("MetadataV14ModuleConstant").new nil
              mc.name = constant.name
              mc.type = Scale::Types::String.new(variant)
              mc.value = constant.value
              mc.docs = constant.docs
              m[:constants][index] = mc
            end
          end

          if m[:storage]
            m[:storage][:items].each_with_index do |item, index|
              unless item[:type][:Plain].nil?
                m[:storage][:items][index][:type][:Plain] = all_portable_hash[item[:type][:Plain]]
              end

              unless item[:type][:Map].nil?
                m[:storage][:items][index][:type][:Map][:key] = all_portable_hash[item[:type][:Map][:key]]
                m[:storage][:items][index][:type][:Map][:value] = all_portable_hash[item[:type][:Map][:value]]
              end
            end
          end
        end
        extrinsic = Scale::Types.get("ExtrinsicMetadataV14").decode(scale_bytes).value
        result.extrinsic = extrinsic
        result.all_portable_hash = all_portable_hash
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
          result[:events] = event
        end

        result[:constants] = Scale::Types.get("Vec<PalletConstantMetadataV14>").decode(scale_bytes).value

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
