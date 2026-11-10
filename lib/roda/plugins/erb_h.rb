# frozen-string-literal: true

require 'erb/escape'

#
class Roda
  module RodaPlugins
    # The erb_h plugin adds an +h+ instance method that will HTML
    # escape the input and return it. This is similar to the h
    # plugin, but it uses erb/escape to implement the HTML escaping,
    # which offers faster performance.
    #
    # To make sure that this speeds up applications using the h
    # plugin, this depends on the h plugin, and overrides the
    # +h+ method.
    #
    # The following example will return <tt>"&lt;foo&gt;"</tt> as the body.
    #
    #   plugin :erb_h
    #
    #   route do |r|
    #     h('<foo>')
    #   end
    #
    # The faster performance offered by the erb_h plugin is due
    # to erb/escape avoiding allocations if not needed (returning the
    # input object if no escaping is needed).  That behavior change
    # can cause problems if you mutate the result of the +h+ method
    # (which can mutate the input), or mutate the input of the +h+
    # method after calling it (which can mutate the result).
    module ErbH
      def self.load_dependencies(app)
        app.plugin :h
      end

      module InstanceMethods
        define_method(:h, ERB::Escape.instance_method(:html_escape))
      end
    end

    register_plugin(:erb_h, ErbH)
  end
end
