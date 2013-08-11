# Possibilities:
#   Find a way to mixin after parse but before execution
#   Add the method when a new string is created


# FIXME: See if we can move this into the class so that we can have
# multiple patches active at once
$counts = 0

class CallPatcher
  attr_reader :target

  def initialize(target)
    @target = target
  end

  def patch
    mod, func, instance_or_class = parse
    if mod.is_a?(Class) && func.is_a?(Symbol)
      patch = "
        class ::#{mod}
          def #{func}_with_counter
            $counts += 1
            #{func}_without_counter
          end
          alias_method :#{func}_without_counter, :#{func}
          alias_method :#{func}, :#{func}_with_counter
        end
      "
      eval(patch)
    else
      # FIXME: Create a watcher that we can target for when methods are
      # added after the fact.
      puts "hi mom"
    end
  end

  def parse
    mod, func = target.split(/[\.#]/)

    begin
      # Create Classes and Symbols to indicate happiness
      mod = Kernel.const_get(mod)
      func = func.to_sym
      if mod.respond_to?(func)
        instance_or_class = :class
      elsif mod.new.respond_to?(func)
        instance_or_class = :instance
      end
    rescue NameError => e
      # Use the string as parsed from above
    end

    return [mod, func, instance_or_class]
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