$counts = 0

class CallPatcher
  class << self
    def patch(target)
      mod, func = parse(target)
      eval("
        class ::#{mod}
          def #{func}_with_counter
            $counts += 1
            #{func}_without_counter
          end
          alias_method :#{func}_without_counter, :#{func}
          alias_method :#{func}, :#{func}_with_counter
        end
      ")
    end

    def parse(target)
      return target.split(/[\.#]/)
    end
  end
end

target = ENV.fetch('COUNT_CALLS_TO') { false }
if target
  CallPatcher.patch(target)
end