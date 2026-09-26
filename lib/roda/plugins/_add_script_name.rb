# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    module AddScriptName_
      module ClassMethods
        RodaPlugins.opt_attr_reader(self, :add_script_name, name: :add_script_name?)
      end
    end

    register_plugin(:_add_script_name, AddScriptName_)
  end
end
