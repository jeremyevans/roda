# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The typecast_params_sized_integers plugin adds sized integer conversion
    # methods to typecast_params:
    #
    # * int8, uint8, pos_int8, pos_uint8, Integer8, Integeru8
    # * int16, uint16, pos_int16, pos_uint16, Integer16, Integeru16
    # * int32, uint32, pos_int32, pos_uint32, Integer32, Integeru32
    # * int64, uint64, pos_int64, pos_uint64, Integer64, Integeru64
    #
    # The int*, pos_int*, and Integer* methods operate the same as the
    # standard int, pos_int, and Integer methods in typecast_params,
    # except that they will only handle parameter values in the given
    # range for the signed integer type.  The uint*, pos_int*, and
    # Integeru* methods are similar to the int*, pos_int*, and
    # Integer* methods, except they use the range of the unsigned
    # integer type instead of the range of the signed integer type.
    #
    # Here are the signed and unsigned integer type ranges:
    # 8 :: [-128, 127], [0, 255]
    # 16 :: [-32768, 32767], [0, 65535]
    # 32 :: [-2147483648, 2147483647], [0, 4294967295]
    # 64 :: [-9223372036854775808, 9223372036854775807], [0, 18446744073709551615]
    #
    # To only create methods for certain integer sizes, you can pass a
    # :sizes option when loading the plugin, and it will only create
    # methods for the sizes you specify.
    #
    # You can provide a :default_size option when loading the plugin,
    # in which case the int, uint, pos_int, pos_uint, Integer, and Integeru,
    # typecast_params conversion methods will be aliases to the conversion
    # methods for the given sized type:
    #
    #  plugin :typecast_params_sized_integers, default_size: 64
    #
    #  route do |r|
    #    # Returns nil unless param.to_i > 0 && param.to_i <= 9223372036854775807
    #    typecast_params.pos_int('param_name')
    #  end
    module TypecastParamsSizedIntegers
      def self.load_dependencies(app, opts=OPTS)
        app.plugin :typecast_params do
          (opts[:sizes] || [8, 16, 32, 64]).each do |i|
            # Avoid defining the same methods more than once
            next if method_defined?(:"pos_int#{i}")

            min_signed = -(2**(i-1))
            max_signed = 2**(i-1)-1
            max_unsigned = 2**i-1

            handle_type(:"int#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_int(v)) && v >= min_signed && v <= max_signed
                v
              end
            end

            handle_type(:"uint#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, negative integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_int(v)) && v >= 0 && v <= max_unsigned
                v
              end
            end

            handle_type(:"pos_int#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, non-positive integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_int(v)) && v > 0 && v <= max_signed
                v
              end
            end

            handle_type(:"pos_uint#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, non-positive integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_int(v)) && v > 0 && v <= max_unsigned
                v
              end
            end

            handle_type(:"Integer#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_Integer(v)) && v >= min_signed && v <= max_signed
                v
              end
            end

            handle_type(:"Integeru#{i}", :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, negative integer, or too-large integer provided for parameter") do |v|
              if (v = base_convert_Integer(v)) && v >= 0 && v <= max_unsigned
                v
              end
            end
          end
        end

        if default = opts[:default_size]
          app::TypecastParams.class_exec do
            meths = ['', 'convert_', '_convert_array_', '_max_input_bytesize_for_', '_invalid_value_message_for_']
            %w[int uint pos_int pos_uint Integer Integeru].each do |type|
              meths.each do |prefix|
                alias_method :"#{prefix}#{type}", :"#{prefix}#{type}#{default}"
              end
              alias_method :"#{type}!", :"#{type}#{default}!"
            end
          end
        end
      end
    end

    register_plugin(:typecast_params_sized_integers, TypecastParamsSizedIntegers)
  end
end
