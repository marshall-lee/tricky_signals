require 'singleton'
require 'forwardable'

class TrickySignals
  class << self
    def global
      Global.instance
    end
  end

  class Global < TrickySignals
    include Singleton

    class << self
      extend Forwardable

      def_delegators :instance,
        :start!,
        :stop!,
        :trap,
        :untrap,
        :untrap_all,
        :ignore_on,
        :default_on,
        :exit_on,
        :system_default_on
    end

    def initialize
      super
      start!
    end
  end
end
