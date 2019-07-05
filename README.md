# DNS Git

[![Build Status](https://travis-ci.org/digineo/dnsgit.svg?branch=master)](https://travis-ci.org/digineo/dnsgit)

Run your own DNS servers and manage your zones easily with Git.

This piece of **free** software gives you the ability to describe your zone
files in a **simple DSL** (Domain Specific Language) with **templates** and
store everything in a **Git repository**.

Every time you push your changes, a hook generates all zone files and increases
serial numbers, if necessary. We have been inspired by [LuaDNS](http://www.luadns.com/).

DNS Git has been tested with:
* [PowerDNS](https://www.powerdns.com/)


## Installation

Please ensure you have Git and a current version of Ruby installed. While
we aim to be compatible with MRI 2.0+, we currently only test against
non-EOL versions (i.e. MRI 2.4+ at the time of writing).

Then clone the repository (on the machine your nameserver runs on) and
install the required libraries using bundler:

```console
$ ssh root@yourserver.example.com
$ git clone git://github.com/digineo/dnsgit /opt/dnsgit
$ cd /opt/dnsgit
$ bundle install
```

Finally, generate a sample configuration.

```console
$ bin/init
Please clone and update the configuration:
  git clone /opt/dnsgit/data dns-config
```


## Configuration

Run these steps locally on your own machine:

```console
$ git clone root@yourserver.example.com:/opt/dnsgit/data dns-config
$ cd dns-config
```

... do some changes ...

```console
$ git add -A
$ git commit -m "my commit message"
$ git push
```


### Examples

Take a look at the [lib/example/](https://github.com/digineo/dnsgit/tree/master/lib/example)
folder and the [tests](https://github.com/digineo/dnsgit/tree/master/tests/zone_test.rb).


## Development

To run tests, simply invoke `rake`.
