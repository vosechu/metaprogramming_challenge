# Possibilities:
#   Find a way to mixin after parse but before execution
#   Add the method when a new string is created


# FIXME: See if we can move this into the class so that we can have
# multiple patches active at once
$counts = 0

class CallPatcher
  attr_reader :target, :mod, :func, :instance_or_class

  def initialize(target)
    @target = target
    @mod, @func, @instance_or_class = parse
  end

  # @public
  def patch
    if method_exists?
      if instance_or_class == :instance
        wrap_method
      elsif instance_or_class == :class
        wrap_class_method
      end
    elsif class_but_not_method_exists?
      watch_for_method
    else
      watch_module
    end
  end

  # @public
  def parse
    mod, func = target.split(/[\.#]/)

    begin
      mod = Kernel.const_get(mod)
      if mod.respond_to?(func)
        func = func.to_sym
        instance_or_class = :class
      elsif mod.new.respond_to?(func)
        func = func.to_sym
        instance_or_class = :instance
      end
    rescue NameError => e
      # Use the string as parsed from above
    end

    return [mod, func, instance_or_class]
  end

  private

  # Data extractions ================================================= #

  def method_exists?
    mod.is_a?(Class) && func.is_a?(Symbol)
  end

  def class_but_not_method_exists?
    mod.is_a?(Class) && func.is_a?(String)
  end

  # Patchers ========================================================= #

  def wrap_method
    mod.module_eval("
      def #{func}_with_counter
        $counts += 1
        #{func}_without_counter
      end
      alias_method :#{func}_without_counter, :#{func}
      alias_method :#{func}, :#{func}_with_counter
    ")
  end

  def wrap_class_method
    # TODO: Complete me
  end

  # Patcher for methods added after the fact. Doesn't work for modules
  # FIXME: Differentiate between instance/class methods
  def watch_for_method
    mod.module_eval("
      def self.method_added(meth)
        if meth == \"#{func}\"
          CallPatcher.new(\"#{target}\").patch
        end
      end
    ")
  end

  # General watcher on Module which watches for a class/module to
  # include another module. There is no hook for a method that's added
  # via `include` so we have to watch for all includes.
  def watch_module
    # FIXME: This should have a method called targets which watches
    # for all target combos
    Module.module_eval("
      def target_module
        \"#{mod}\"
      end

      def target
        \"#{target}\"
      end

      def include_with_watcher(*args)
        include_without_watcher(*args)
        if target_module == self.to_s
          CallPatcher.new(target).patch
        end
      end
      alias_method :include_without_watcher, :include
      alias_method :include, :include_with_watcher
    ")
  end
end

# FIXME: Can we clean this up a little bit? I'd like to not have the
# `require` kick off the whole process.
target = ENV.fetch('COUNT_CALLS_TO') { false }
if target
  CallPatcher.new(target).patch

  at_exit do
    puts "#{target} called #{$counts} times"
  end
end