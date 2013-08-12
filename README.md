## Description

This is a small function counter which is capable of giving you a rough idea
how many times a function is called during runtime via stdout without
sacrificing too much performance.

Response to: https://gist.github.com/samg/5b287544800f8a6cddf2

## Test runner

`rspec` or `bundle && autotest`

## Performance

### With class constant counter storage (256% time)

Using a class constant hash for storage really hit hard. I was surprised
by this but it makes sense. Still, I left it in the code because I wanted
to present something more readable.

$ time COUNT_CALLS_TO='B#foo' ruby -r ./lib/solution.rb -e 'module A; def foo; end; end; class B; include A; end; 10000000.times{B.new.foo}'
B#foo called 10000000 times
6.54s user 0.01s system 99% cpu 6.554 total
6.31s user 0.01s system 99% cpu 6.333 total
6.36s user 0.01s system 99% cpu 6.378 total

### With global variable counter storage (136% time)

Switching out the class constants to just use globals was a massive speedup.
The only problem is that I feel like this isn't going to work on a project
the scale of New Relic so I didn't want to present it. Reducing the number
of operations is important but being able to instrument many things is also
important.

$ time COUNT_CALLS_TO='B#foo' ruby -r ./lib/solution.rb -e 'module A; def foo; end; end; class B; include A; end; 10000000.times{B.new.foo}'
B#foo called 10000000 times
3.41s user 0.01s system 99% cpu 3.423 total
3.34s user 0.01s system 99% cpu 3.355 total
3.54s user 0.01s system 99% cpu 3.555 total

### Without counter library

Raw benchmark. Run three times to achieve an average.

$ time COUNT_CALLS_TO='B#foo' ruby -e 'module A; def foo; end; end; class B; include A; end; 10000000.times{B.new.foo}'
2.58s user 0.01s system 99% cpu 2.597 total
2.43s user 0.01s system 99% cpu 2.445 total
2.47s user 0.01s system 99% cpu 2.479 total