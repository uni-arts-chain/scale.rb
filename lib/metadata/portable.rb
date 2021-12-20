class Portable
  attr_accessor :all_portable_hash

  def initialize
    @all_portable_hash = {}
  end

  def compact_all_types(portables, id=nil)
    portables = portables[:id] if !id.nil?
    
    portables.each do |portable|
      unless portable[:type][:def][:Primitive].nil?
        @all_portable_hash[portable[:id].to_i] = portable[:type][:def][:Primitive]
        Scale::TypeRegistry.instance.add_custom_type({"PrimitiveTypes_#{portable[:type][:def][:Primitive]}" => portable[:type][:def][:Primitive]})
      end
    end
  
    portables.each do |portable|
      if portable[:type][:path].size > 0 &&  portable[:type][:path][0] == "sp_core"
        deal_one_si_type(portables, portable[:id])
      end
    end
  
    portables.each do |portable|
      sub_type = @all_portable_hash[portable[:id]]
      if sub_type.nil?
        deal_one_si_type(portables, portable[:id])
      else
        next
      end
    end
  end
  
  def expand_composite(portables, id)
    type_string = name_si_type(portables, id)
    portable = portables[id]
    composite = portable[:type][:def][:Composite]
    if composite[:fields].size == 1
      sub_type_id = composite[:fields][0][:type].to_i
      sub_type = @all_portable_hash[sub_type_id]
      if sub_type.nil?
        sub_type = deal_one_si_type(portables, composite[:fields][0][:type].to_i)
      end
      Scale::TypeRegistry.instance.add_custom_type({type_string => sub_type})
      @all_portable_hash[id] = sub_type
      return @all_portable_hash[id]
    end
  
    type_mapping = []
    composite[:fields].each do |field|
      sub_type_id = field[:type].to_i
      sub_type = @all_portable_hash[sub_type_id]
      if sub_type.nil?
        sub_type = deal_one_si_type(portables, sub_type_id)
      end
      type_mapping << [field[:name], sub_type]
    end
    struct = {
      "type" => "struct",
      "type_mapping":type_mapping
    }
    Scale::TypeRegistry.instance.add_custom_type({type_string => struct})
    @all_portable_hash[id] = type_string
    return @all_portable_hash[id]
  end
  
  def expand_array(portables, id)
    portable = portables[id]
    sub_type_id = portable[:type][:def][:Array][:type].to_i
    if portable[:type][:def][:Array][:len] == 0
      @all_portable_hash[portable[:id].to_i] = "Null"
      return "Null"
    end
    sub_type = @all_portable_hash[sub_type_id]
    if sub_type.nil?
      sub_type = deal_one_si_type(portables, sub_type_id)
    end
    @all_portable_hash[portable[:id].to_i] = "[#{sub_type}; #{portable[:type][:def][:Array][:len]}]"
    "[#{sub_type}; #{portable[:type][:def][:Array][:len]}]"
  end
  
  def expand_sequence (portables, id)
    portable = portables[id]
    sub_type_id = portable[:type][:def][:Sequence][:type].to_i
    sub_type = @all_portable_hash[sub_type_id]
    if sub_type.nil?
      sub_type = deal_one_si_type(portables, sub_type_id)
    end
    @all_portable_hash[id] = "Vec<#{sub_type}>"
    return @all_portable_hash[id]
  end
  
  def expand_tuple (portables, id)
    portable = portables[id]
    if portable[:type][:def][:Tuple].nil?
      return "Null"
    end
    tuples = []
    portable[:type][:def][:Tuple].each_with_index do |field, index|
      sub_type_id = field.to_i
      sub_type = @all_portable_hash[sub_type_id]
      if sub_type.nil?
        sub_type = deal_one_si_type(portables, sub_type_id)
      end
      tuples << sub_type
    end
    # Scale::Types.get(struct)
    name = "Tuple" + tuples.join(",")
    struct = "(#{tuples.join(',')})"
    Scale::TypeRegistry.instance.add_custom_type({name => struct})
    @all_portable_hash[id] = name
    return @all_portable_hash[id]
  end
  
  def expand_compact(portables, id)
    portable = portables[id]
    sub_type_id = portable[:type][:def][:Compact][:type].to_i
    sub_type = @all_portable_hash[sub_type_id]
    if sub_type.nil?
      sub_type = deal_one_si_type(portables, sub_type_id)
    end
    @all_portable_hash[id] = "Compact<#{sub_type}>"
    return @all_portable_hash[id]
  end
  
  def expand_option portables, id
    portable = portables[id]
    sub_type_id = portable[:type][:params][0][:type].to_i
    sub_type = @all_portable_hash[sub_type_id]
    if sub_type.nil?
      sub_type = deal_one_si_type(portables, sub_type_id)
    end
    @all_portable_hash[id] = "Option<#{sub_type}>"
    return @all_portable_hash[id]
  end
  
  def expand_result portables, id
    portable = portables[id]
    sub_type_id = portable[:type][:params][0][:type].to_i
    sub_type = @all_portable_hash[sub_type_id]
    if sub_type.nil?
      sub_type = deal_one_si_type(portables, sub_type_id)
    end
    err_type_id = portable[:type][:params][1][:type].to_i
    err_type = @all_portable_hash[err_type_id]
    if err_type.nil?
      err_type = deal_one_si_type(portables, err_type_id)
    end
    @all_portable_hash[id] = "Results<#{sub_type},#{err_type}>"
    return @all_portable_hash[id]
  end
  
  def expand_enum portables, id
    portable = portables[id]
    type_name = "null"
    value_enum = false
    enum_value_list = []
    types = []
    portable[:type][:def][:Variant][:variants].sort_by {|variant| variant[:index]}
  
    portable[:type][:def][:Variant][:variants].each_with_index do |variant, index|
      struct_types = []
      if variant[:fields].size == 0
        enum_value_list << [variant[:name], "#{variant[:index]}"]
      elsif variant[:fields].size == 1
        value_enum = true
        sub_type_id = variant[:fields][0][:type].to_i
        sub_type = @all_portable_hash[sub_type_id]
        if sub_type.nil?
          sub_type = deal_one_si_type(portables, sub_type_id)
        end
        type_name = sub_type
      else
        value_enum = true
        variant[:fields].each_with_index do |field, index|
          sub_type_id = field[:type].to_i
          sub_type = @all_portable_hash[sub_type_id]
          if sub_type.nil?
            sub_type = deal_one_si_type(portables, sub_type_id)
          end
  
          if field[:name] == ""
            field[:name] = "col#{index}"
          end
  
          struct_types << [field[:name], sub_type]
        end
  
        if struct_types.size > 0
          type_name = struct_types.to_s
        end
      end
  
      interval = variant[:index]
      if index > 0
        interval = variant[:index] - portable[:type][:def][:Variant][:variants][index - 1][:index] - 1
      end
  
      while interval > 0
        types << ["empty", "Null"]
        interval = interval -1
      end
  
      types <<  [variant[:name], type_name]
    end
  
    if !value_enum
          types = enum_value_list
    end
    typeString = name_si_type(portables, id)
    @all_portable_hash[id] = typeString
    struct = {
      "type" => "enum",
      "type_mapping":types
    }
    Scale::TypeRegistry.instance.add_custom_type({typeString => struct})
    return @all_portable_hash[id]
  end
  
  def deal_one_si_type portables, id, recursive=false
    portable = portables[id]
  
    if recursive
      si_type_name = name_si_type portables, id
      if si_type_name != ""
        return si_type_name
      end
    end
  
    unless portable[:type][:def][:Composite].nil?
      return expand_composite portables, id
    end
  
    unless portable[:type][:def][:Array].nil?
      return expand_array  portables, id
    end
  
    unless portable[:type][:def][:Sequence].nil?
      return expand_sequence  portables, id
    end
  
    unless portable[:type][:def][:Tuple].nil?
      return expand_tuple  portables, id
    end
  
    unless portable[:type][:def][:Compact].nil?
      return expand_compact portables, id
    end
  
    unless portable[:type][:def][:BitSequence].nil?
      @all_portable_hash[id] = "BitVec"
      return @all_portable_hash[id]
    end
  
    # todo
    unless portable[:type][:def][:SiTypeDefRange].nil?
     
    end
  
    unless portable[:type][:def][:Variant].nil?
      special_variant = portable[:type][:path][0]
  
      if special_variant.downcase == "option"
        return expand_option portables, id
      end
  
      if special_variant.downcase == "result"
        return expand_result portables, id
      end
  
      len = portable[:type][:path].size
      if len >=2 && portable[:type][:path][len -2] == "pallet" && portable[:type][:path][len -1] == "Call"
        @all_portable_hash[id] = "Call"
        return @all_portable_hash[id]
      elsif !["Call", "Event"].include?(portable[:type][:path][len -1])
        @all_portable_hash[id] = "Call"
        return @all_portable_hash[id]
      else
        return expand_enum portables, id
      end 
    end
  
    @all_portable_hash[id] = "Null"
    return  @all_portable_hash[id]
  end
  
  def name_si_type(portables, id)
    portable = portables[id]
    unless portable[:type][:def][:Composite].nil?
      return (portable[:type][:path].join(':')  + "_#{id}").capitalize
    end
  
    unless portable[:type][:def][:Variant].nil?
      special_variant = portable[:type][:path][0]
  
      if special_variant.downcase == "option" || special_variant.downcase == "result"
        return ""
      end
  
      len = portable[:type][:path].size
      if len >=2 && portable[:type][:path][len -2] == "pallet" && portable[:type][:path][len -1] == "Call"
        return ""
      elsif !["Call", "Event"].include?(portable[:type][:path][len -1])
        return ""
      else
        return portable[:type][:path].join(':').capitalize
      end
    end
    return ""
  end
end