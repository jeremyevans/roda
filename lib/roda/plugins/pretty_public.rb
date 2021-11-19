# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The pretty_public plugin builds upon the functionality of the public
    # plugin by adding support for extensionless files and index files within
    # folders. For example:
    #
    #   /path/to/file => /path/to/file.html
    #   /another/path => /another/path/index.html
    #
    # It will work either with or without a trailing slash as well.
    #
    # By default the extension it looks for is .html, but you can configure
    # it with a list of extensions. You can also switch the default behavior
    # so it looks for a file first before looking for a folder with an index
    # file.
    #
    # Examples:
    #
    #   # Use public folder as location of files
    #   plugin :pretty_public
    #
    #   # Use output folder as location, look for additional extensions
    #   plugin :pretty_public, root: "output", extensions: [:html, :htm, :txt]
    #
    #   # Prioritize files (file.html) before folders (file/index.html)
    #   plugin :pretty_public, file_before_folder: true
    #
    #   # Make GET /pages/foo/ look for public/pages/foo/index.html
    #   route do |r|
    #     r.pretty_public
    #   end
    module PrettyPublic
      def self.load_dependencies(app, opts=OPTS)
        app.plugin(:public, opts)
      end

      # Override the default pretty URL options. Any other options are passed
      # to the public plugin.
      # :extensions :: An array of file extensions (html, htm, etc.)
      # :file_before_folder :: Whether to look for a file first before looking
      #                        for an index file in the folder
      def self.configure(app, opts=OPTS)
        app.opts[:pretty_public_extensions] = opts[:extensions] || [:html]
        app.opts[:pretty_public_file_before_folder] = opts[:file_before_folder]
      end

      module ClassMethods
        # Freeze the array of extensions when freezing the app
        def freeze
          opts[:pretty_public_extensions].freeze
          super
        end
      end

      module RequestMethods
        # Serve files from the public folder if the file exists and this is a GET request.
        def pretty_public
          public
        end

        # Get the segments processed by the public plugin and check for
        # extensionless files and indexes if necessary
        def public_path_segments(path)
          segments = super

          check_path = ::File.join(roda_class.opts[:public_root], *segments)
          unless ::File.file?(check_path)
            if roda_class.opts[:pretty_public_file_before_folder]
              segments_modified = check_path_files(segments, check_path)
              check_path_indexes(segments, check_path) unless segments_modified
            else
              segments_modified = check_path_indexes(segments, check_path)
              check_path_files(segments, check_path) unless segments_modified
            end
          end

          segments
        end

        def check_path_indexes(segments, path)
          segments_modified = false

          roda_class.opts[:pretty_public_extensions].each do |ext|
            check_path = check_path_index_with_extension(path, ext)
            if check_path
              segments << check_path
              segments_modified = true
              break
            end
          end

          segments_modified
        end
    
        def check_path_files(segments, path)
          segments_modified = false
          last_segment = segments.last

          roda_class.opts[:pretty_public_extensions].each do |ext|
            if ::File.file?("#{path}.#{ext}")
              segments[-1] = "#{last_segment}.#{ext}"
              segments_modified = true
              break
            end
          end

          segments_modified
        end

        def check_path_index_with_extension(path, ext)
          filename = "index.#{ext}"
          check_path = ::File.join(path, filename)
          ::File.file?(check_path) ? filename : nil
        end
      end
    end

    register_plugin(:pretty_public, PrettyPublic)
  end
end
