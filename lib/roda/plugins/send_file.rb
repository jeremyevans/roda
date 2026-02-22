# frozen-string-literal: true

begin
  require 'rack/files'
rescue LoadError
  require 'rack/file'
end

#
class Roda
  module RodaPlugins
    # The send_file plugin adds a send_file method, used for
    # returning the contents of a file as the body of a request.
    # It also loads the response_attachment plugin to set the
    # Content-Disposition and Content-Type based on the file's
    # extension.
    #
    # senf_file will serve the file with the given path from the file system:
    #
    #   send_file 'path/to/file.txt'
    #
    # Options:
    #
    # :disposition :: Set the Content-Disposition to the given disposition.
    # :filename :: Set the Content-Disposition to attachment (unless :disposition is set),
    #              and set the filename parameter to the value.
    # :last_modified :: Explicitly set the Last-Modified header to the given value, and
    #                   return a not modified response if there has not been modified since
    #                   the previous request.  This option requires the caching plugin.
    # :status :: Override the status for the response.
    # :type :: Set the Content-Type to use for this response.
    #
    # == License
    #
    # The implementation was originally taken from Sinatra,
    # which is also released under the MIT License:
    #
    # Copyright (c) 2007, 2008, 2009 Blake Mizerany
    # Copyright (c) 2010, 2011, 2012, 2013, 2014 Konstantin Haase
    # 
    # Permission is hereby granted, free of charge, to any person
    # obtaining a copy of this software and associated documentation
    # files (the "Software"), to deal in the Software without
    # restriction, including without limitation the rights to use,
    # copy, modify, merge, publish, distribute, sublicense, and/or sell
    # copies of the Software, and to permit persons to whom the
    # Software is furnished to do so, subject to the following
    # conditions:
    # 
    # The above copyright notice and this permission notice shall be
    # included in all copies or substantial portions of the Software.
    # 
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    # EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    # OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    # NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    # HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    # WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    # FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    # OTHER DEALINGS IN THE SOFTWARE.
    module SendFile
      RACK_FILES = defined?(Rack::Files) ? Rack::Files : Rack::File

      # Depend on the status_303 plugin.
      def self.load_dependencies(app)
        app.plugin :response_attachment
      end

      module InstanceMethods
        # Use the contents of the file at +path+ as the response body.  See plugin documentation for options.
        def send_file(path, opts = OPTS)
          r = @_request
          res = @_response
          headers = res.headers
          if (type = opts[:type]) || !headers[RodaResponseHeaders::CONTENT_TYPE]
            type_str = type.to_s

            if type_str.include?('/')
              type = type_str
            else
              if type
                type = ".#{type}" unless type_str.start_with?(".")
              else
                type = ::File.extname(path)
              end

              type &&= Rack::Mime.mime_type(type, nil)
              type ||= 'application/octet-stream'
            end
            
            headers[RodaResponseHeaders::CONTENT_TYPE] = type
          end

          disposition = opts[:disposition]
          filename    = opts[:filename]
          if disposition || filename
            disposition ||= 'attachment'
            filename = path if filename.nil?
            res.attachment(filename, disposition)
          end

          if lm = opts[:last_modified]
            r.last_modified(lm)
          end

          file = RACK_FILES.new nil
          s, h, b = if Rack.release > '2'
            file.serving(r, path)
          else
            file.path = path
            file.serving(env)
          end

          res.status = opts[:status] || s
          headers.delete(RodaResponseHeaders::CONTENT_LENGTH)
          headers.replace(h.merge!(headers))
          r.halt res.finish_with_body(b)
        rescue Errno::ENOENT
          response.status = 404
          r.halt
        end
      end
    end

    register_plugin(:send_file, SendFile)
  end
end
