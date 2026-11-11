# frozen-string-literal: true

require 'mail'

class Roda
  module RodaPlugins
    # The error_mail plugin adds an +error_mail+ instance method that
    # send an email related to the exception.  This is designed to be used
    # with the error_handler plugin:
    #
    #   plugin :error_mail, to: 'to@example.com', from: 'from@example.com'
    #   plugin :error_handler do |e|
    #     error_mail(e)
    #     'Internal Server Error'
    #   end
    #
    # It is similar to the error_email plugin, except that it uses the mail
    # library instead of net/smtp directly.  If you are already using the
    # mail library in your application, it makes sense to use error_mail
    # instead of error_email.
    #
    # Options:
    #
    # +:filter+ :: Callable called with the key and value for each parameter, environment
    #              variable, and session value.  If it returns true, the value of the
    #              parameter is filtered in the email.
    # +:from+ :: The From address to use in the email (required)
    # +:headers+ :: A hash of additional headers to use in the email (default: empty hash)
    # +:prefix+ :: A prefix to use in the email's subject line (default: no prefix)
    # +:to+ :: The To address to use in the email (required)
    #
    # The subject of the error email shows the exception class and message.
    # The body of the error email shows the backtrace of the error and the
    # request environment, as well the request params and session variables (if any).
    # You can also call error_mail with a plain string instead of an exception,
    # in which case the string is used as the subject, and no backtrace is included.
    #
    # Note that emailing on every error as shown above is only appropriate
    # for low traffic web applications.  For high traffic web applications,
    # use an error reporting service instead of this plugin.
    module ErrorMail
      DEFAULT_FILTER = lambda{|k,v| false}
      private_constant :DEFAULT_FILTER

      PLUGIN_ARGUMENTS = %i[to from headers prefix filter].freeze 
      private_constant :PLUGIN_ARGUMENTS

      Config = Struct.new(*PLUGIN_ARGUMENTS)
      private_constant :Config

      # Set default opts for plugin.  See ErrorEmail module RDoc for options.
      def self.configure(app, opts=OPTS)
        RodaPlugins.check_supported_opts("the error_mail plugin", opts, PLUGIN_ARGUMENTS)

        app.opts[:error_mail] = email_opts = (app.error_mail_opts || {:filter=>DEFAULT_FILTER}).merge(opts).freeze
        unless email_opts[:to] && email_opts[:from]
          raise RodaError, "must provide :to and :from options to error_mail plugin"
        end

        app.opts[:error_mail_config] = Config.new(*email_opts.values_at(*Config.members)).freeze
      end

      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :error_mail, name: :error_mail_opts)
        RodaPlugins.opt_attr_reader(self, :error_mail_config)
      end

      module InstanceMethods
        # Send an email for the given error.  +exception+ is usually an exception
        # instance, but it can be a plain string which is used as the subject for
        # the email.
        def error_mail(exception)
          _error_mail(exception).deliver!
        end

        # The content of the email to send, include the headers and the body.
        # Takes the same argument as #error_mail.
        def error_mail_content(exception)
          _error_mail(exception).to_s
        end

        private

        def _error_mail(e)
          config = self.class.error_mail_config
          subject = if e.respond_to?(:message)
            "#{e.class}: #{e.message}"
          else
            e.to_s
          end
          subject = "#{config.prefix}#{subject}"
          filter = config.filter

          format = lambda do |h|
            h = h.map{|k, v| "#{k.inspect} => #{filter.call(k, v) ? 'FILTERED' : v.inspect}"}
            h.sort!
            h.join("\n")
          end 

          begin
            params = request.params
            params = (format[params] unless params.empty?)
          rescue
            params = 'Invalid Parameters!'
          end

          message = String.new
          message << <<END
Path: #{request.path}

END
          if e.respond_to?(:backtrace)
            message << <<END
Backtrace:

#{e.backtrace.join("\n")}
END
          end

          message << <<END

ENV:

#{format[env]}
END

          if params
            message << <<END

Params:

#{params}
END
          end

          if env['rack.session']
            message << <<END

Session:

#{format[session]}
END
          end


          Mail.new do
            from config.from
            to config.to
            subject subject
            body message

            if headers = config.headers
              headers.each do |k,v|
                header[k] = v
              end
            end
          end
        end
      end
    end

    register_plugin(:error_mail, ErrorMail)
  end
end
