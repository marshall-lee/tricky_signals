tricky_signals
==============

[![Build Status](https://travis-ci.org/marshall-lee/tricky_signals.svg)](https://travis-ci.org/marshall-lee/tricky_signals)

This gem aims to solve the problem with...

```ruby
logger = Logger.new(STDOUT)
trap('USR1') do
  logger.info 'hello!'
end
```

And then:

```
kill -USR1 <pid>
```

What we get:

```
log writing failed. can't be called from trap context
```

Looks familiar? Then `tricky_signals` is your friend!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'tricky_signals'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tricky_signals

## Usage

### Global trap handlers

```ruby
logger = Logger.new(STDOUT)

# ...

TrickySignals.global.trap(:USR1) do
  Thread.list.each do |thread|
    logger.debug { "Thread object_id=#{thread.object_id}" }
    if thread.backtrace
      logger.debug { thread.backtrace.join("\n") }
    else
      logger.debug '<no backtrace available>'
    end
  end
end
```

### Global untrap

```ruby
TrickySignals.global.untrap(:USR1)
```

### Manual starting of service

```ruby
TrickySignals.start! do |signals|
  signals.trap(:USR1) { }
  # subscribed to USR1
  signals.trap(:TTIN) { }
  # subscribed to TTIN
  # ...
end
# unsubscribed from USR1 and TTIN
```

#### Manual stop
```ruby
signals = TrickySignals.start!
signals.trap(:USR1) { }
signals.trap(:TTIN) { }
# ...
signals.stop!
# unsubscribed from USR1 and TTIN
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marshall-lee/tricky_signals.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

