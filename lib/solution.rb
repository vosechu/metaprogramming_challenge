# Possibilities:
#   Find a way to mixin after parse but before execution
#   Add the method when a new string is created
#   Alias-method-chain
#   Detect includes on class, check for methods then

class CallPatcher
  COUNTS = {} if !defined?(COUNTS)

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
    elsif class_exists_but_no_method?
      watch_for_method_definition
    else
      watch_for_module_include
    end

    # Singleton method
    CallPatcher.register_exit_function
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

  # Singleton methods ================================================ #

  def self.register_exit_function
    return if @exit_registered # singleton variable

    at_exit do
      CallPatcher::COUNTS.each do |key, count|
        puts "#{key} called #{count} times"
      end
    end
    @exit_registered = true
  end

  # Data extractions ================================================= #

  def method_exists?
    mod.is_a?(Class) && func.is_a?(Symbol)
  end

  def class_exists_but_no_method?
    mod.is_a?(Class) && !mod.respond_to?(func.to_sym)
  end

  # Patchers ========================================================= #

  def wrap_method
    if CallPatcher::COUNTS[target].nil?
      COUNTS[target] = 0

      mod.module_eval("
        def #{func}_with_counter
          CallPatcher::COUNTS['#{target}'] += 1
          #{func}_without_counter
        end
        alias_method :#{func}_without_counter, :#{func}
        alias_method :#{func}, :#{func}_with_counter
      ")
    end
  end

  def wrap_class_method
    # Not in spec
  end

  # Patcher for methods added after the fact. Doesn't work for modules
  def watch_for_method_definition
    mod.module_eval("
      def self.method_added(meth)
        if meth == \"#{func}\".to_sym
          CallPatcher.new(\"#{target}\").patch
        end
      end

      def self.singleton_method_added(meth)
        if meth == \"#{func}\"
          CallPatcher.new(\"#{target}\").patch
        end
      end
    ")
  end

  # General watcher on Module which watches for a class/module to
  # include another module. There is no hook for a method that's added
  # via `include` so we have to watch for all includes.
  def watch_for_module_include
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

# Slight mod from idiom, check if script run from command-line or via
# the -e flag
if $0 == __FILE__ || $0 == '-e'
  target = ENV.fetch('COUNT_CALLS_TO') do
    throw ArgumentError.new('call program with `COUNT_CALLS_TO="String#size" ruby -r ./lib/solution.rb -e \'(1..100).each{|i| i.to_s.size if i.odd? }\'')
  end

  if target
    CallPatcher.new(target).patch
  end
end