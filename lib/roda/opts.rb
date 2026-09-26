# frozen-string-literal: true

class Roda
  class RodaOpts < Hash
    # The Roda class to set instance variables on when calling #[]=
    attr_writer :roda_class

    # If duplicating the hash, detach the Roda class.
    def initialize_copy(_)
      super
      @roda_class = nil
    end

    # Set an <tt>@opt_*</tt> instance variable in the Roda class if it is tied
    # to a Roda class.
    def []=(k, v)
      super
      @roda_class.instance_variable_set(:"@opt_#{k}", v) if @roda_class
      v
    end
  end
end
