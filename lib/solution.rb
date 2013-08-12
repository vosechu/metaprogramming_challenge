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
      # # Patcher for methods added after the fact. Doesn't work for modules
      # # being included
      # patch = "
      #   class ::#{mod}
      #     def self.method_added(meth)
      #       if meth == \"#{func}\"
      #         puts \"Patching...\"
      #         CallPatcher.new(\"#{target}\").patch
      #       else
      #         puts \"not Patching...\"
      #         puts meth
      #       end
      #     end
      #   end
      # "
      # puts patch
      # eval(patch)
      patch = "
        class ::Module
          def include_with_watcher(*args)
            include_without_watcher(*args)
            if \"#{mod}\" == self.to_s
              CallPatcher.new(\"#{target}\").patch
            end
          end
          alias_method :include_without_watcher, :include
          alias_method :include, :include_with_watcher
        end
      "
      eval(patch)
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