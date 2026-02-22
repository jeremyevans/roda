# frozen-string-literal: true

require 'rack/mime'

#
class Roda
  module RodaPlugins
    # The attachment plugin adds a response.attachment method.
    # When called with no filename, +attachment+ just sets the Content-Disposition
    # to attachment.  When called with a filename, this sets the Content-Disposition
    # to attachment with the appropriate filename parameter, and if the filename
    # extension is recognized, this also sets the Content-Type to the appropriate
    # MIME type if not already set.
    #
    #   attachment          # set Content-Disposition to 'attachment'
    #   attachment 'a.csv'  # set Content-Disposition to 'attachment;filename="a.csv"',
    #                       # also set Content-Type to 'text/csv'
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
    module ResponseAttachment
      UTF8_ENCODING = Encoding.find('UTF-8')
      ISO88591_ENCODING = Encoding.find('ISO-8859-1')
      BINARY_ENCODING = Encoding.find('BINARY')

      module ResponseMethods
        # Set the Content-Disposition to "attachment" with the specified filename,
        # instructing the user agents to prompt to save.
        def attachment(filename = nil, disposition='attachment')
          if filename
            param_filename = File.basename(filename)
            encoding = param_filename.encoding

            needs_encoding = param_filename.gsub!(/[^ 0-9a-zA-Z!\#$&\+\.\^_`\|~]+/, '-')
            params = "; filename=#{param_filename.inspect}"

            if needs_encoding && (encoding == UTF8_ENCODING || encoding == ISO88591_ENCODING)
              # File name contains non attr-char characters from RFC 5987 Section 3.2.1

              encoded_filename = File.basename(filename).force_encoding(BINARY_ENCODING)
              # Similar regexp as above, but treat each byte separately, and encode
              # space characters, since those aren't allowed in attr-char
              encoded_filename.gsub!(/[^0-9a-zA-Z!\#$&\+\.\^_`\|~]/) do |c|
                "%%%X" % c.ord
              end

              encoded_params = "; filename*=#{encoding.to_s}''#{encoded_filename}"
            end

            unless @headers[RodaResponseHeaders::CONTENT_TYPE]
              ext = File.extname(filename)
              if !ext.empty? && (content_type = Rack::Mime.mime_type(ext, nil))
                @headers[RodaResponseHeaders::CONTENT_TYPE] = content_type
              end
            end
          end

          @headers[RodaResponseHeaders::CONTENT_DISPOSITION] = "#{disposition}#{params}#{encoded_params}"
        end
      end
    end

    register_plugin(:response_attachment, ResponseAttachment)
  end
end
