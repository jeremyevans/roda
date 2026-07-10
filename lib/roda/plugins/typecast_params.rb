# frozen-string-literal: true

require 'date'
require 'time'

class Roda
  module RodaPlugins
    # The typecast_params plugin allows for type conversion of submitted parameters.
    # Submitted parameters should be considered untrusted input, and in standard use
    # with browsers, parameters are submitted as strings (or a hash/array containing
    # strings).  In most cases it makes sense to explicitly convert the parameter to the
    # desired type.  While this can be done via manual conversion:
    #
    #   val = request.params['key'].to_i
    #   val = nil unless val > 0
    #
    # the typecast_params plugin adds a friendlier interface:
    #
    #   val = typecast_params.pos_int('key')
    #
    # As +typecast_params+ is a fairly long method name, and may be a method you call
    # frequently, you may want to consider aliasing it to something more terse in your
    # application, such as +tp+.
    #
    # typecast_params offers support for default values:
    #
    #   val = typecast_params.pos_int('key', 1)
    #
    # The default value is only used if no value has been submitted for the parameter,
    # or if the conversion of the value results in +nil+.  Handling defaults for parameter
    # conversion manually is more difficult, since the parameter may not be present at all,
    # or it may be present but an empty string because the user did not enter a value on
    # the related form.  Use of typecast_params for the conversion handles both cases.
    #
    # In many cases, parameters should be required, and if they aren't submitted, that
    # should be considered an error.  typecast_params handles this with ! methods:
    #
    #   val = typecast_params.pos_int!('key')
    #
    # These ! methods raise an error instead of returning +nil+, and do not allow defaults.
    #
    # The errors raised by this plugin use a specific exception class,
    # +Roda::RodaPlugins::TypecastParams::Error+.  This allows you to handle
    # this specific exception class globally and return an appropriate 4xx
    # response to the client.  You can use the Error#param_name and Error#reason 
    # methods to get more information about the error.
    #
    # To make it easy to handle cases where many parameters need the same conversion
    # done, you can pass an array of keys to a conversion method, and it will return an array
    # of converted values:
    #
    #   val1, val2 = typecast_params.pos_int(['key1', 'key2'])
    #
    # This is equivalent to:
    #
    #   val1 = typecast_params.pos_int('key1')
    #   val2 = typecast_params.pos_int('key2')
    #
    # The ! methods also support arrays, ensuring that all parameters have a value:
    #
    #   val1, val2 = typecast_params.pos_int!(['key1', 'key2'])
    #
    # For handling of array parameters, where all entries in the array use the
    # same conversion, there is an +array+ method which takes the type as the first argument
    # and the keys to convert as the second argument:
    #
    #   vals = typecast_params.array(:pos_int, 'keys')
    #
    # If you want to ensure that all entries in the array are converted successfully and that
    # there is a value for the array itself, you can use +array!+:
    #
    #   vals = typecast_params.array!(:pos_int, 'keys')
    #
    # This will raise an exception if any of the values in the array for parameter +keys+ cannot
    # be converted to integer.
    #
    # Both +array+ and +array!+ support default values which are used if no value is present
    # for the parameter:
    #
    #   vals1 = typecast_params.array(:pos_int, 'keys1', [])
    #   vals2 = typecast_params.array!(:pos_int, 'keys2', [])
    #
    # You can also pass an array of keys to +array+ or +array!+, if you would like to perform
    # the same conversion on multiple arrays:
    #
    #   foo_ids, bar_ids = typecast_params.array!(:pos_int, ['foo_ids', 'bar_ids'])
    #
    # The previous examples have shown use of the +pos_int+ method, which uses +to_i+ to convert the
    # value to an integer, but returns +nil+ if the resulting integer is not positive.  Unless you need
    # to handle negative numbers, it is recommended to use +pos_int+ instead of +int+ as +int+ will
    # convert invalid values to 0 (since that is how <tt>String#to_i</tt> works).
    #
    # There are many built in methods for type conversion:
    #
    # any :: Returns the value as is without conversion
    # str :: Raises if value is not already a string
    # nonempty_str :: Raises if value is not already a string, and converts
    #                 the empty string or string containing only whitespace to +nil+
    # bool :: Converts entry to boolean if in one of the recognized formats:
    #         nil :: nil, ''
    #         true :: true, 1, '1', 't', 'true', 'yes', 'y', 'on' # case insensitive
    #         false :: false, 0, '0', 'f', 'false', 'no', 'n', 'off' # case insensitive
    #         If not in one of those formats, raises an error.
    # int :: Converts value to integer using +to_i+ (note that invalid input strings will be
    #        returned as 0)
    # pos_int :: Converts value using +to_i+, but non-positive values are converted to +nil+
    # Integer :: Converts value to integer using <tt>Kernel::Integer</tt>, with base 10 for
    #            string inputs, and a check that the output value is equal to the input
    #            value for numeric inputs.
    # float :: Converts value to float using +to_f+ (note that invalid input strings will be
    #          returned as 0.0)
    # Float :: Converts value to float using <tt>Kernel::Float(value)</tt>
    # Hash :: Raises if value is not already a hash
    # date :: Converts value to Date using <tt>Date.parse(value)</tt>
    # time :: Converts value to Time using <tt>Time.parse(value)</tt>
    # datetime :: Converts value to DateTime using <tt>DateTime.parse(value)</tt>
    # file :: Raises if value is not already a hash with a :tempfile key whose value
    #         responds to +read+ (this is the format rack uses for uploaded files).
    #
    # All of these methods also support ! methods (e.g. +pos_int!+), and all of them can be
    # used in the +array+ and +array!+ methods to support arrays of values.
    #
    # Since parameter hashes can be nested, the <tt>[]</tt> method can be used to access nested
    # hashes:
    #
    #   # params: {'key'=>{'sub_key'=>'1'}}
    #   typecast_params['key'].pos_int!('sub_key') # => 1
    #
    # This works to an arbitrary depth:
    #
    #   # params: {'key'=>{'sub_key'=>{'sub_sub_key'=>'1'}}}
    #   typecast_params['key']['sub_key'].pos_int!('sub_sub_key') # => 1
    #
    # And also works with arrays at any depth, if those arrays contain hashes:
    #
    #   # params: {'key'=>[{'sub_key'=>{'sub_sub_key'=>'1'}}]}
    #   typecast_params['key'][0]['sub_key'].pos_int!('sub_sub_key') # => 1
    #
    #   # params: {'key'=>[{'sub_key'=>['1']}]}
    #   typecast_params['key'][0].array!(:pos_int, 'sub_key') # => [1]
    #
    # To allow easier access to nested data, there is a +dig+ method:
    #
    #   typecast_params.dig(:pos_int, 'key', 'sub_key')
    #   typecast_params.dig(:pos_int, 'key', 0, 'sub_key', 'sub_sub_key')
    #
    # +dig+ will return +nil+ if any access while looking up the nested value returns +nil+.
    # There is also a +dig!+ method, which will raise an Error if +dig+ would return +nil+:
    #
    #   typecast_params.dig!(:pos_int, 'key', 'sub_key')
    #   typecast_params.dig!(:pos_int, 'key', 0, 'sub_key', 'sub_sub_key')
    #
    # Note that none of these conversion methods modify +request.params+.  They purely do the
    # conversion and return the converted value.  However, in some cases it is useful to do all
    # the conversion up front, and then pass a hash of converted parameters to an internal
    # method that expects to receive values in specific types.  The +convert!+ method does
    # this, and there is also a +convert_each!+ method
    # designed for converting multiple values using the same block:
    #
    #   converted_params = typecast_params.convert! do |tp|
    #     tp.int('page')
    #     tp.pos_int!('artist_id')
    #     tp.array!(:pos_int, 'album_ids')
    #     tp.convert!('sales') do |stp|
    #       stp.pos_int!(['num_sold', 'num_shipped'])
    #     end
    #     tp.convert!('members') do |mtp|
    #       mtp.convert_each! do |stp|
    #         stp.str!(['first_name', 'last_name'])
    #       end
    #     end
    #   end
    #
    #   # converted_params:
    #   # {
    #   #   'page' => 1,
    #   #   'artist_id' => 2,
    #   #   'album_ids' => [3, 4],
    #   #   'sales' => {
    #   #     'num_sold' => 5,
    #   #     'num_shipped' => 6
    #   #   },
    #   #   'members' => [
    #   #      {'first_name' => 'Foo', 'last_name' => 'Bar'},
    #   #      {'first_name' => 'Baz', 'last_name' => 'Quux'}
    #   #   ]
    #   # }
    #
    # +convert!+ and +convert_each!+ only return values you explicitly specify for conversion
    # inside the passed block.
    # 
    # You can specify the +:symbolize+ option to +convert!+ or +convert_each!+, which will
    # symbolize the resulting hash keys:
    #
    #   converted_params = typecast_params.convert!(symbolize: true) do |tp|
    #     tp.int('page')
    #     tp.pos_int!('artist_id')
    #     tp.array!(:pos_int, 'album_ids')
    #     tp.convert!('sales') do |stp|
    #       stp.pos_int!(['num_sold', 'num_shipped'])
    #     end
    #     tp.convert!('members') do |mtp|
    #       mtp.convert_each! do |stp|
    #         stp.str!(['first_name', 'last_name'])
    #       end
    #     end
    #   end
    #
    #   # converted_params:
    #   # {
    #   #   :page => 1,
    #   #   :artist_id => 2,
    #   #   :album_ids => [3, 4],
    #   #   :sales => {
    #   #     :num_sold => 5,
    #   #     :num_shipped => 6
    #   #   },
    #   #   :members => [
    #   #      {:first_name => 'Foo', :last_name => 'Bar'},
    #   #      {:first_name => 'Baz', :last_name => 'Quux'}
    #   #   ]
    #   # }
    #
    # Using the +:symbolize+ option makes it simpler to transition from untrusted external
    # data (string keys), to semitrusted data that can be used internally (trusted in the sense that
    # the expected types are used, not that you trust the values).
    #
    # Note that if there are multiple conversion errors raised inside a +convert!+ or +convert_each!+ 
    # block, they are recorded and a single TypecastParams::Error instance is raised after
    # processing the block.  TypecastParams::Error#param_names can be called on the exception to
    # get an array of all parameter names with conversion issues, and TypecastParams::Error#all_errors
    # can be used to get an array of all Error instances.
    #
    # Because of how +convert!+ and +convert_each!+ work, you should avoid calling
    # TypecastParams::Params#[] inside the block you pass to these methods, because if the #[]
    # call fails, it will skip the reminder of the block.
    #
    # Be aware that when you use +convert!+ and +convert_each!+, the conversion methods called
    # inside the block may return nil if there is a error raised, and nested calls to
    # +convert!+ and +convert_each!+ may not return values.
    #
    # When loading the typecast_params plugin, a subclass of +TypecastParams::Params+ is created
    # specific to the Roda application.  You can add support for custom types by passing a block
    # when loading the typecast_params plugin.  This block is executed in the context of the
    # subclass, and calling +handle_type+ in the block can be used to add conversion methods.
    # +handle_type+ accepts a type name, an options hash, and the block used to convert the type.
    # Supported options are:
    # +:invalid_value_message+ :: The message to use for type conversions that result in a nil value
    #                             (a space and the parameter name is appended to this).
    # +:max_input_bytesize+ :: The maximum bytesize of string input.
    # 
    # You can override the invalid value message of an existing type using the
    # +invalid_value_message+ method.  You can also override the max input bytesize of an existing
    # type using the +max_input_bytesize+ method.
    #
    #   plugin :typecast_params do
    #     handle_type(:album, max_input_bytesize: 100,
    #                 invalid_value_message: "invalid album id in parameter") do |value|
    #       if id = convert_pos_int(val)
    #         Album[id]
    #       end
    #     end
    #     max_input_bytesize(:date, 256)
    #     invalid_value_message(:pos_int, "value must be greater than 0 for parameter")
    #   end
    #
    # By default, the typecast_params conversion procs are passed the parameter value directly
    # from +request.params+ without modification.  In some cases, it may be beneficial to
    # strip leading and trailing whitespace from parameter string values before processing, which
    # you can do by passing the <tt>strip: :all</tt> option when loading the plugin.
    #
    # By default, the typecasting methods for some types check whether the bytesize of input
    # strings is over the maximum expected values, and raise an error in such cases. The input
    # bytesize is checked prior to any type conversion.  If you would like to skip this check
    # and allow any bytesize when doing type conversion for param string values, you can do so by
    # passing the # <tt>:skip_bytesize_checking</tt> option when loading the plugin. By default,
    # there is an 100 byte limit on integer input, an 1000 byte input on float input, and a 128
    # byte limit on date/time input.
    #
    # By default, the typecasting methods check whether input strings have null bytes, and raise
    # an error in such cases.  This check for null bytes occurs prior to any type conversion.
    # If you would like to skip this check and allow null bytes in param string values,
    # you can do so by passing the <tt>:allow_null_bytes</tt> option when loading the plugin.
    #
    # You can use the :date_parse_input_handler option to specify custom handling of date
    # parsing input.  Modern versions of Ruby and the date gem internally raise if the input to
    # date parsing methods is too large to prevent denial of service.  If you are using an
    # older version of Ruby, you can use this option to enforce the same check:
    #
    #   plugin :typecast_params, date_parse_input_handler: proc {|string|
    #       raise ArgumentError, "too big" if string.bytesize > 128
    #       string
    #     }
    #
    # You can also use this option to modify the input, such as truncating it to the first
    # 128 bytes:
    #
    #   plugin :typecast_params, date_parse_input_handler: proc {|string|
    #       string.b[0, 128]
    #     }
    #
    # The +date_parse_input_handler+ is only called if the value is under the max input
    # bytesize, so you may need to call +max_input_bytesize+ for the +:date+, +:time+, and
    # +:datetime+ methods to override the max input bytesize if you want to use this option
    # for input strings over 128 bytes.
    #
    # By design, typecast_params only deals with string keys, it is not possible to use
    # symbol keys as arguments to the conversion methods and have them converted.
    module TypecastParams
      SCOPE_INSTANCE_VARIABLES = [:@_typecast_params, :@_typecast_query_params, :@_typecast_body_params].freeze

      # Sentinal value for whether to raise exception during #process
      CHECK_NIL = Object.new.freeze

      # Exception class for errors that are caused by misuse of the API by the programmer.
      # These are different from +Error+ which are raised because the submitted parameters
      # do not match what is expected.  Should probably be treated as a 5xx error.
      class ProgrammerError < RodaError; end

      # Exception class for errors that are due to the submitted parameters not matching
      # what is expected.  Should probably be treated as a 4xx error.
      class Error < RodaError
        # Set the keys in the given exception.  If the exception is not already an
        # instance of the class, create a new instance to wrap it.
        def self.create(keys, reason, e)
          if e.is_a?(self)
            e.keys ||= keys
            e.reason ||= reason
            e
          else
            backtrace = e.backtrace
            e = new("#{e.class}: #{e.message}")
            e.keys = keys
            e.reason = reason
            e.set_backtrace(backtrace) if backtrace
            e
          end
        end

        # The keys used to access the parameter that caused the error.  This is an array
        # that can be splatted to +dig+ to get the value of the parameter causing the error.
        attr_accessor :keys

        # An array of all other errors that were raised with this error.  If the error
        # was not raised inside Params#convert! or Params#convert_each!, this will just be
        # an array containing the current receiver.
        # 
        # This allows you to use Params#convert! to process a form input, and if any
        # conversion errors occur inside the block, it can provide an array of all parameter
        # names and reasons for parameters with problems.
        attr_writer :all_errors

        def all_errors
          @all_errors ||= [self]
        end

        # The reason behind this error.  If this error was caused by a conversion method,
        # this will be the conversion method symbol.  If this error was caused
        # because a value was missing, then it will be +:missing+.  If this error was
        # caused because a value was not the correct type, then it will be +:invalid_type+.
        attr_accessor :reason

        # The likely parameter name where the contents were not expected.  This is
        # designed for cases where the parameter was submitted with the typical
        # application/x-www-form-urlencoded or multipart/form-data content types,
        # and assumes the typical rack parsing of these content types into
        # parameters.  # If the parameters were submitted via JSON, #keys should be
        # used directly.
        # 
        # Example:
        # 
        #   # keys: ['page']
        #   param_name => 'page'
        # 
        #   # keys: ['artist', 'name']
        #   param_name => 'artist[name]'
        # 
        #   # keys: ['album', 'artist', 'name']
        #   param_name => 'album[artist][name]'
        def param_name
          if keys.length > 1
            first, *rest = keys
            v = first.dup
            rest.each do |param|
              v << "["
              v << param unless param.is_a?(Integer)
              v << "]"
            end
            v
          else
            keys.first
          end
        end

        # An array of all parameter names for parameters where the context were not
        # expected.  If Params#convert! was not used, this will be an array containing
        # #param_name.  If Params#convert! was used and multiple exceptions were
        # captured inside the convert! block, this will contain the parameter names
        # related to all captured exceptions.
        def param_names
          all_errors.map(&:param_name)
        end
      end

      module AllowNullByte
        private

        # Allow ASCII NUL bytes ("\0") in parameter string values.
        def check_null_byte(v)
        end
      end

      module StringStripper
        private

        # Strip any resulting input string.
        def param_value(key)
          v = super

          if v.is_a?(String)
            v = v.strip
          end

          v
        end
      end

      module DateParseInputHandler
        # Pass input string to date parsing through handle_date_parse_input.
        def _string_parse!(klass, v)
          v = handle_date_parse_input(v)
          super
        end
      end

      module SkipBytesizeChecking
        private

        # Do not check max input bytesize
        def check_allowed_bytesize(v, max)
        end
      end

      # Class handling conversion of submitted parameters to desired types.
      class Params
        # Handle conversions for the given type using the given block.
        # For a type named +foo+, this will create the following methods:
        #
        # * foo(key, default=nil)
        # * foo!(key)
        # * convert_foo(value) # private
        # * _convert_array_foo(value) # private
        # * _invalid_value_message_for_foo # private
        # * _max_input_bytesize_for_foo # private
        #
        # This method is used to define all type conversions, even the built
        # in ones.  It can be called in subclasses to setup subclass-specific
        # types.
        def self.handle_type(type, opts=OPTS, &block)
          convert_meth = :"convert_#{type}"
          define_method(convert_meth, &block)

          convert_array_meth = :"_convert_array_#{type}"
          define_method(convert_array_meth) do |v|
            raise Error, "expected array but received #{v.inspect}" unless v.is_a?(Array)
            v.map! do |val|
              check_allowed_bytesize(val, _max_input_bytesize_for(type))
              check_null_byte(val)
              send(convert_meth, val)
            end
          end

          private convert_meth, convert_array_meth

          invalid_value_message(type, opts[:invalid_value_message])
          max_input_bytesize(type, opts[:max_input_bytesize])

          define_method(type) do |key, default=nil|
            process_arg(convert_meth, key, default, type) if require_hash!
          end

          define_method(:"#{type}!") do |key|
            send(type, key, CHECK_NIL)
          end
        end

        # Set the invalid message for the given type.
        def self.invalid_value_message(type, message)
          invalid_value_message_meth = :"_invalid_value_message_for_#{type}"
          define_method(invalid_value_message_meth){message}
          private invalid_value_message_meth
          alias_method invalid_value_message_meth, invalid_value_message_meth
        end

        # Set the maximum input bytesize for the given type.
        def self.max_input_bytesize(type, bytesize)
          max_input_bytesize_meth = :"_max_input_bytesize_for_#{type}"
          define_method(max_input_bytesize_meth){bytesize}
          private max_input_bytesize_meth
          alias_method max_input_bytesize_meth, max_input_bytesize_meth
        end

        # Create a new instance with the given object and nesting level.
        # +obj+ should be an array or hash, and +nesting+ should be an
        # array.  Designed for internal use, should not be called by
        # external code.
        def self.nest(obj, nesting)
          v = allocate
          v.instance_variable_set(:@nesting, nesting)
          v.send(:initialize, obj)
          v
        end

        handle_type(:any) do |v|
          v
        end

        handle_type(:str) do |v|
          raise Error, "expected string but received #{v.inspect}" unless v.is_a?(::String)
          v
        end

        handle_type(:nonempty_str, :invalid_value_message=>"empty string provided for parameter") do |v|
          if (v = convert_str(v)) && !v.strip.empty?
            v
          end
        end

        handle_type(:bool, :invalid_value_message=>"empty string provided for parameter") do |v|
          case v
          when ''
            nil
          when false, 0, /\A(?:0|f(?:alse)?|no?|off)\z/i
            false
          when true, 1, /\A(?:1|t(?:rue)?|y(?:es)?|on)\z/i
            true
          else
            raise Error, "expected bool but received #{v.inspect}"
          end
        end

        handle_type(:int, :max_input_bytesize=>100, :invalid_value_message=>"empty string provided for parameter") do |v|
          string_or_numeric!(v) && v.to_i
        end
        alias base_convert_int convert_int

        handle_type(:pos_int, :max_input_bytesize=>100, :invalid_value_message=>"empty string, non-integer, or non-positive integer provided for parameter") do |v|
          if (v = base_convert_int(v)) && v > 0
            v
          end
        end

        handle_type(:Integer, :max_input_bytesize=>100, :invalid_value_message=>"empty string provided for parameter") do |v|
          if string_or_numeric!(v)
            case v
            when String
              ::Kernel::Integer(v, 10)
            when Integer
              v
            else
              i = ::Kernel::Integer(v)
              raise Error, "numeric value passed to Integer contains non-Integer part: #{v.inspect}" unless i == v
              i
            end
          end
        end
        alias base_convert_Integer convert_Integer

        handle_type(:float, :max_input_bytesize=>1000, :invalid_value_message=>"empty string provided for parameter") do |v|
          string_or_numeric!(v) && v.to_f
        end

        handle_type(:Float, :max_input_bytesize=>1000, :invalid_value_message=>"empty string provided for parameter") do |v|
          string_or_numeric!(v) && ::Kernel::Float(v)
        end

        handle_type(:Hash) do |v|
          raise Error, "expected hash but received #{v.inspect}" unless v.is_a?(::Hash)
          v
        end

        handle_type(:date, :max_input_bytesize=>128) do |v|
          parse!(::Date, v)
        end

        handle_type(:time, :max_input_bytesize=>128) do |v|
          parse!(::Time, v)
        end

        handle_type(:datetime, :max_input_bytesize=>128) do |v|
          parse!(::DateTime, v)
        end

        handle_type(:file) do |v|
          raise Error, "expected hash with :tempfile entry" unless v.is_a?(::Hash) && v.has_key?(:tempfile) && v[:tempfile].respond_to?(:read)
          v
        end

        # Set the object used for converting.  Conversion methods will convert members of
        # the passed object.
        def initialize(obj)
          case @obj = obj
          when Hash, Array
            # nothing
          else
            if @nesting
              handle_error(nil, (@obj.nil? ? :missing : :invalid_type), "value of #{param_name(nil)} parameter not an array or hash: #{obj.inspect}", true)
            else
              handle_error(nil, :invalid_type, "parameters given not an array or hash: #{obj.inspect}", true)
            end
          end
        end

        # If key is a String Return whether the key is present in the object,
        def present?(key)
          case key
          when String
            !any(key).nil?
          when Array
            key.all? do |k|
              raise ProgrammerError, "non-String element in array argument passed to present?: #{k.inspect}" unless k.is_a?(String)
              !any(k).nil?
            end
          else
            raise ProgrammerError, "unexpected argument passed to present?: #{key.inspect}"
          end
        end

        # Return a new Params instance for the given +key+. The value of +key+ should be an array
        # if +key+ is an integer, or hash otherwise.
        def [](key)
          @subs ||= {}
          if sub = @subs[key]
            return sub
          end

          if @obj.is_a?(Array)
            unless key.is_a?(Integer)
              handle_error(key, :invalid_type, "invalid use of non-integer key for accessing array: #{key.inspect}", true)
            end
          else
            if key.is_a?(Integer)
              handle_error(key, :invalid_type, "invalid use of integer key for accessing hash: #{key}", true)
            end
          end

          v = @obj[key]
          v = yield if v.nil? && defined?(yield)

          begin
            sub = self.class.nest(v, Array(@nesting) + [key])
          rescue => e
            handle_error(key, :invalid_type, e, true)
          end

          @subs[key] = sub
          sub.sub_capture(@capture, @symbolize, @skip_missing)
          sub
        end

        # Return the nested value for key. If there is no nested_value for +key+,
        # calls the block to return the value, or returns nil if there is no block given.
        def fetch(key)
          send(:[], key){return(yield if defined?(yield))}
        end

        # Captures conversions inside the given block, and returns a hash of all conversions,
        # including conversions of subkeys.  +keys+ should be an array of subkeys to access,
        # or nil to convert the current object. If +keys+ is given as a hash, it is used as
        # the options hash. Options:
        #
        # :raise :: If set to false, do not raise errors for missing keys
        # :skip_missing :: If set to true, does not store values if the key is not
        #                  present in the params.
        # :symbolize :: Convert any string keys in the resulting hash and for any
        #               conversions below
        def convert!(keys=nil, opts=OPTS)
          if keys.is_a?(Hash)
            opts = keys
            keys = nil
          end

          _capture!(:nested_params, opts) do
            if sub = subkey(Array(keys).dup, opts.fetch(:raise, true))
              yield sub
            end
          end
        end

        # Runs conversions similar to convert! for each key specified by the :keys option.  If :keys option is not given
        # and the object is an array, runs conversions for all entries in the array.  If the :keys
        # option is not given and the object is a Hash with string keys '0', '1', ..., 'N' (with
        # no skipped keys), runs conversions for all entries in the hash.  If :keys option is a Proc
        # or a Method, calls the proc/method with the current object, which should return an
        # array of keys to use.
        # Supports options given to #convert!, and this additional option:
        #
        # :keys :: The keys to extract from the object. If a proc or method,
        #          calls the value with the current object, which should return the array of keys
        #          to use.
        def convert_each!(opts=OPTS, &block)
          np = !@capture

          _capture!(nil, opts) do
            case keys = opts[:keys]
            when nil
              keys = (0...@obj.length)

              valid = if @obj.is_a?(Array)
                true
              else
                keys = keys.map(&:to_s)
                keys.all?{|k| @obj.has_key?(k)}
              end

              unless valid
                handle_error(nil, :invalid_type, "convert_each! called on object not an array or hash with keys '0'..'N'")
                next 
              end
            when Array
              # nothing to do
            when Proc, Method
              keys = keys.call(@obj)
            else
              raise ProgrammerError, "unsupported convert_each! :keys option: #{keys.inspect}"
            end

            keys.map do |i|
              begin
                if v = subkey([i], opts.fetch(:raise, true))
                  yield v
                  v.nested_params if np 
                end
              rescue => e
                handle_error(i, :invalid_type, e)
              end
            end
          end
        end

        # Convert values nested under the current obj.  Traverses the current object using +nest+, then converts
        # +key+ on that object using +type+:
        #
        #   tp.dig(:pos_int, 'foo')               # tp.pos_int('foo')
        #   tp.dig(:pos_int, 'foo', 'bar')        # tp['foo'].pos_int('bar')
        #   tp.dig(:pos_int, 'foo', 'bar', 'baz') # tp['foo']['bar'].pos_int('baz')
        #
        # Returns nil if any of the values are not present or not the expected type. If the nest path results
        # in an object that is not an array or hash, then raises an Error.
        #
        # You can use +dig+ to get access to nested arrays by using <tt>:array</tt> or <tt>:array!</tt> as
        # the first argument and providing the type in the second argument:
        #
        #   tp.dig(:array, :pos_int, 'foo', 'bar', 'baz')  # tp['foo']['bar'].array(:pos_int, 'baz')
        def dig(type, *nest, key)
          _dig(false, type, nest, key)
        end

        # Similar to +dig+, but raises an Error instead of returning +nil+ if no value is found.
        def dig!(type, *nest, key)
          _dig(true, type, nest, key)
        end

        # Convert the value of +key+ to an array of values of the given +type+. If +default+ is
        # given, any +nil+ values in the array are replaced with +default+.  If +key+ is an array
        # then this returns an array of arrays, one for each respective value of +key+. If there is
        # no value for +key+, nil is returned instead of an array.
        def array(type, key, default=nil)
          meth = :"_convert_array_#{type}"
          raise ProgrammerError, "no typecast_params type registered for #{type.inspect}" unless respond_to?(meth, true)
          process_arg(meth, key, default, type) if require_hash!
        end

        # Call +array+ with the +type+, +key+, and +default+, but if the return value is nil or any value in
        # the returned array is +nil+, raise an Error.
        def array!(type, key, default=nil)
          v = array(type, key, default)

          if key.is_a?(Array)
            key.zip(v).each do |k, arr|
              check_array!(k, arr)
            end
          else
            check_array!(key, v)
          end

          v
        end

        protected

        # Recursively descendent into all known subkeys and get the converted params from each.
        def nested_params
          return @nested_params if @nested_params

          params = @params

          if @subs
            @subs.each do |key, v|
              if key.is_a?(String) && symbolize?
                key = key.to_sym
              end
              params[key] = v.nested_params
            end
          end
          
          params
        end

        # Recursive method to get subkeys.
        def subkey(keys, do_raise)
          unless key = keys.shift
            return self
          end

          reason = :invalid_type

          case key
          when String
            unless @obj.is_a?(Hash)
              raise Error, "parameter #{param_name(nil)} is not a hash" if do_raise
              return
            end
            present = !@obj[key].nil?
          when Integer
            unless @obj.is_a?(Array)
              raise Error, "parameter #{param_name(nil)} is not an array" if do_raise
              return
            end
            present = key < @obj.length
          else
            raise ProgrammerError, "invalid argument used to traverse parameters: #{key.inspect}"
          end

          unless present
            reason = :missing
            raise Error, "parameter #{param_name(key)} is not present" if do_raise
            return
          end

          self[key].subkey(keys, do_raise)
        rescue => e
          handle_error(key, reason, e)
        end

        # Inherit given capturing and symbolize setting from parent object.
        def sub_capture(capture, symbolize, skip_missing)
          if @capture = capture
            @symbolize = symbolize
            @skip_missing = skip_missing
            @params = @obj.class.new
          end
        end
        
        private

        # Whether to symbolize keys when capturing.  Note that the method
        # is renamed to +symbolize?+.
        attr_reader :symbolize
        alias symbolize? symbolize
        undef symbolize

        # Internals of convert! and convert_each!.
        def _capture!(ret, opts)
          previous_symbolize = @symbolize
          previous_skip_missing = @skip_missing

          unless cap = @capture
            @params = @obj.class.new
            @subs.clear if @subs
            capturing_started = true
            cap = @capture = []
          end

          if opts.has_key?(:symbolize)
            @symbolize = !!opts[:symbolize]
          end
          if opts.has_key?(:skip_missing)
            @skip_missing = !!opts[:skip_missing]
          end

          begin
            v = yield
          rescue Error => e
            cap << e unless cap.last == e
          end

          if capturing_started
            unless cap.empty?
              e = cap[0]
              e.all_errors = cap
              raise e
            end

            if ret == :nested_params
              nested_params
            else
              v
            end
          end
        ensure
          @nested_params = nil

          if capturing_started
            # Unset capturing if capturing was already started.
            @capture = nil
          else
            # If capturing was not already started, update cached nested params
            # before resetting symbolize setting. 
            @nested_params = nested_params
          end

          @symbolize = previous_symbolize
          @skip_missing = previous_skip_missing
        end

        # Raise an error if the array given does contains nil values.
        def check_array!(key, arr)
          if arr
            if arr.any?{|val| val.nil?}
              handle_error(key, :invalid_type, "invalid value in array parameter #{param_name(key)}")
            end
          else
            handle_error(key, :missing, "missing parameter for #{param_name(key)}")
          end
        end

        # Internals of dig/dig!
        def _dig(force, type, nest, key)
          if type == :array || type == :array!
            conv_type = nest.shift
            unless conv_type.is_a?(Symbol)
              raise ProgrammerError, "incorrect subtype given when using #{type} as argument for dig/dig!: #{conv_type.inspect}"
            end
            meth = type
            type = conv_type
            args = [meth, type]
          else
            meth = type
            args = [type]
          end

          unless respond_to?("_convert_array_#{type}", true)
            raise ProgrammerError, "no typecast_params type registered for #{meth.inspect}"
          end

          if v = subkey(nest, force)
            v.send(*args, key, (CHECK_NIL if force))
          end
        end

        # Format a reasonable parameter name value, for use in exception messages.
        def param_name(key)
          first, *rest = keys(key)
          if first
            v = first.dup
            rest.each do |param|
              v << "[#{param}]"
            end
            v
          end
        end

        # If +key+ is not +nil+, add it to the given nesting.  Otherwise, just return the given nesting.
        # Designed for use in setting the +keys+ values in raised exceptions.
        def keys(key)
          Array(@nesting) + Array(key)
        end

        # Handle any conversion errors.  By default, reraises Error instances with the keys set,
        # converts ::ArgumentError instances to Error instances, and reraises other exceptions.
        def handle_error(key, reason, e, do_raise=false)
          case e
          when String
            handle_error(key, reason, Error.new(e), do_raise)
          when Error, ArgumentError
            if @capture && (le = @capture.last) && le == e
              raise e if do_raise
              return
            end

            e = Error.create(keys(key), reason, e)

            if @capture
              @capture << e
              raise e if do_raise
              nil
            else
              raise e
            end
          else
            raise e
          end
        end

        # Issue an error unless the current object is a hash.  Used to ensure we don't try to access
        # entries if the current object is an array.
        def require_hash!
          @obj.is_a?(Hash) || handle_error(nil, :invalid_type, "expected hash object in #{param_name(nil)} but received array object")
        end

        # If +key+ is not an array, convert the value at the given +key+ using the +meth+ method and +default+
        # value.  If +key+ is an array, return an array with the conversion done for each respective member of +key+.
        def process_arg(meth, key, default, type)
          case key
          when String
            v = process(meth, key, default, type)

            if @capture
              key = key.to_sym if symbolize?
              if !@skip_missing || @obj.has_key?(key)
                @params[key] = v
              end
            end

            v
          when Array
            key.map do |k|
              raise ProgrammerError, "non-String element in array argument passed to typecast_params: #{k.inspect}" unless k.is_a?(String)
              process_arg(meth, k, default, type)
            end
          else
            raise ProgrammerError, "Unsupported argument for typecast_params conversion method: #{key.inspect}"
          end
        end

        # The invalid message to use if the given type conversion fails, which may be nil to use the default.
        def _invalid_value_message_for(type)
          send(:"_invalid_value_message_for_#{type}")
        end

        # The maximum input bytesize for the given type, which may be nil.
        def _max_input_bytesize_for(type)
          send(:"_max_input_bytesize_for_#{type}")
        end

        # Raise an Error if the value is a string with bytesize over max (if max is given)
        def check_allowed_bytesize(v, max)
          if max && v.is_a?(String) && v.bytesize > max
            handle_error(nil, :too_long, "string parameter is too long for type", true)
          end
        end

        # Raise an Error if the value is a string containing a null byte.
        def check_null_byte(v)
          if v.is_a?(String) && v.index("\0")
            handle_error(nil, :null_byte, "string parameter contains null byte", true)
          end
        end

        # Get the value of +key+ for the object, and convert it to the expected type using +meth+.
        # If the value either before or after conversion is nil, return the +default+ value.
        def process(meth, key, default, type)
          orig_v = v = param_value(key)

          if v.nil?
            if default == CHECK_NIL
              handle_error(key, :missing, "missing parameter for #{param_name(key)}")
            end
          else
            check_allowed_bytesize(v, _max_input_bytesize_for(type))
            check_null_byte(v)
            v = send(meth, v)
          end

          if v.nil?
            if !orig_v.nil? && default == CHECK_NIL
              invalid_value_message = _invalid_value_message_for(type)
              invalid_value_message ||= "invalid parameter value for"
              handle_error(key, :invalid_value, "#{invalid_value_message} #{param_name(key)}")
            end

            default
          else
            v
          end
        rescue => e
          handle_error(key, meth.to_s.sub(/\A_?convert_/, '').to_sym, e)
        end

        # Get the value for the given key in the object.
        def param_value(key)
          @obj[key]
        end

        # Helper for conversion methods where '' should be considered nil,
        # and only String or Numeric values should be converted.
        def string_or_numeric!(v)
          case v
          when ''
            nil
          when String, Numeric
            true
          else
            raise Error, "unexpected value received: #{v.inspect}"
          end
        end

        # Helper for conversion methods where '' should be considered nil,
        # and only String values should be converted by calling +parse+ on
        # the given +klass+.
        def parse!(klass, v)
          case v
          when ''
            nil
          when String
            _string_parse!(klass, v)
          else
            raise Error, "unexpected value received: #{v.inspect}"
          end
        end

        # Handle parsing for string values passed to parse!.
        def _string_parse!(klass, v)
          klass.parse(v)
        end
      end

      # Set application-specific Params subclass unless one has been set,
      # and if a block is passed, eval it in the context of the subclass.
      # Respect the <tt>strip: :all</tt> to strip all parameter strings
      # before processing them.
      def self.configure(app, opts=OPTS, &block)
        app.const_set(:TypecastParams, Class.new(RodaPlugins::TypecastParams::Params)) unless app.const_defined?(:TypecastParams)
        app::TypecastParams.class_eval(&block) if block
        if opts[:strip] == :all
          app::TypecastParams.send(:include, StringStripper)
        end
        if opts[:allow_null_bytes]
          app::TypecastParams.send(:include, AllowNullByte)
        end
        if opts[:skip_bytesize_checking]
          app::TypecastParams.send(:include, SkipBytesizeChecking)
        end
        if opts[:date_parse_input_handler]
          app::TypecastParams.class_eval do
            include DateParseInputHandler
            define_method(:handle_date_parse_input, &opts[:date_parse_input_handler])
            private :handle_date_parse_input
            alias handle_date_parse_input handle_date_parse_input
          end
        end
      end

      module ClassMethods
        # Freeze the Params subclass when freezing the class.
        def freeze
          self::TypecastParams.freeze
          super
        end

        # Assign the application subclass a subclass of the current Params subclass.
        def inherited(subclass)
          super
          subclass.const_set(:TypecastParams, Class.new(self::TypecastParams))
        end
      end

      module InstanceMethods
        # Return and cache the instance of the TypecastParams class wrapping access
        # to the request's params (merging query string params and body params).
        # Type conversion methods will be called on the result of this method.
        def typecast_params
          @_typecast_params ||= self.class::TypecastParams.new(@_request.params)
        end

        # Return and cache the instance of the TypecastParams class wrapping
        # access to parameters in the request's query string.
        # Type conversion methods will be called on the result of this method.
        def typecast_query_params
          @_typecast_query_params ||= self.class::TypecastParams.new(@_request.GET)
        end

        # Return and cache the instance of the TypecastParams class wrapping
        # access to parameters in the request's body.
        # Type conversion methods will be called on the result of this method.
        def typecast_body_params
          @_typecast_body_params ||= self.class::TypecastParams.new(@_request.POST)
        end
      end
    end

    register_plugin(:typecast_params, TypecastParams)
  end
end
