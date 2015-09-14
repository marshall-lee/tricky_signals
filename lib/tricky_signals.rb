require 'thread'
require 'monitor.rb'

class TrickySignals
  class Handlers
  end

  class << self
    def start!
      obj = new.start!
      if block_given?
        yield obj
        obj.stop!
      else
        obj
      end
    end

    def handlers_class
      const_get(:Handlers)
    end
  end

  include MonitorMixin

  def initialize
    super
    @started = false
  end

  def start!
    synchronize do
      fail "cannot start #{self}: already started!" if @started
      @started = true

      @handlers = self.class.handlers_class.new
      @previous = {}
      @io_thread = start_io
      self
    end
  end

  def stop!
    synchronize do
      fail "cannot stop #{self}: not started or stopped" unless @started

      untrap_all

      stop_io
      @previous = nil
      @handlers = nil

      @started = false
      nil
    end
  end

  def started?
    @started
  end

  def handlers
    synchronize do
      check_started!
      @handlers
    end
  end

  def setup_handlers
    fail 'you should pass a block to `setup_handlers`' unless block_given?

    synchronize do
      check_started!
      @handlers.instance_eval(&proc)
    end
  end

  def trap(signal, command = nil)
    synchronize do
      check_started!
      signal = stringify_signal(signal)
      prev_handler =
        if block_given?
          trap_with_block(signal, &proc)
        else
          trap_with_command(signal, command)
        end
      @previous[signal] = prev_handler unless @previous.key? signal
      prev_handler
    end
  end

  def untrap(signal)
    synchronize do
      check_started!
      signal = stringify_signal(signal)
      if @previous.key? signal
        trap_with_command(signal, @previous[signal])
        @previous.delete signal
      end
    end
  end

  def untrap_all
    synchronize do
      check_started!
      @previous.keys.each { |signal| untrap signal }
    end
  end

  {
    ignore: 'IGNORE',
    default: 'DEFAULT',
    exit: 'EXIT',
    system_default: 'SYSTEM_DEFAULT'
  }.each do |name, command|
    name = "#{name}_on"

    define_method(name) do |signal, &block|
      trap(signal, command)
    end
  end

  private

  def check_started!
    fail "#{self} is not started yet!" unless @started
  end

  def start_io
    @io_read, @io_write = IO.pipe

    Thread.new do
      while ios = IO.select([@io_read])
        input = ios.first.first.gets
        break unless input
        signal = input.chomp

        synchronize do
          handler = @handlers.public_method("handle_#{signal}")
          case handler.arity
          when 0 then handler.call
          when 1 then handler.call signal
          when 2 then handler.call signal, @previous[signal]
          end
        end
      end

      @io_read.close
    end
  end

  def stop_io
    @io_write.close
    @io_thread.join
    @io_thread = nil
    @io_read = nil
    @io_write = nil
  end

  def trap_with_block(signal, &block)
    @handlers.define_singleton_method("handle_#{signal}", &block)
    Signal.trap(signal) do
      @io_write.puts(signal)
    end
  end

  def trap_with_command(signal, command)
    sclass = @handlers.singleton_class
    if sclass.method_defined?(method_name_for(signal))
      sclass.send(:remove_method, method_name_for(signal))
    end
    Signal.trap(signal, command)
  end

  if Signal.respond_to? :signame
    def signame(signal)
      Signal.signame(signal).to_s
    end
  else
    def signame(signal)
      found = Signal.list.find { |name, i| i == signal }
      fail ArgumentError, "unknow signal #{signal}" unless found
      found.first.to_s
    end
  end

  def stringify_signal(signal)
    if signal.is_a? Fixnum
      signame(signal)
    else
      signal.to_s
    end
  end

  def method_name_for(signal)
    "handle_#{signal}"
  end
end

require 'tricky_signals/global'
require 'tricky_signals/version'
