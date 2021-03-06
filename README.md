# hostname.cr
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://chris-huxtable.github.io/hostname.cr/)
[![GitHub release](https://img.shields.io/github/release/chris-huxtable/hostname.cr.svg)](https://github.com/chris-huxtable/hostname.cr/releases)
[![Build Status](https://travis-ci.org/chris-huxtable/hostname.cr.svg?branch=master)](https://travis-ci.org/chris-huxtable/hostname.cr)

Encapsulates hostnames making them more convenient.


## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  hostname:
    github: chris-huxtable/hostname.cr
```


## Usage

```crystal
require "hostname"
```

Some samples:
```crystal
hostname0 = Hostname["example.com"]
hostname1 = Hostname["example.com"]?
hostname2 = Hostname.new("example.com")
hostname3 = Hostname.new?("example.com")

an_address = hostname0.address?()
adresses = hostname0.addresses()

hostname0.each_address() { |address|
	puts address
}
```


## Contributing

1. Fork it ( https://github.com/chris-huxtable/hostname.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request


## Contributors

- [Chris Huxtable](https://github.com/chris-huxtable) - creator, maintainer
