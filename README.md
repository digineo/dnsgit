# DNS Git

[![CircleCI](https://circleci.com/gh/digineo/dnsgit.svg?style=svg)](https://circleci.com/gh/digineo/dnsgit)

Run your own DNS servers and manage your zones easily with Git.

This piece of free software gives you the ability to describe your zone
files in a **simple DSL** (Domain Specific Language) with **templates**
and store everything in a **Git repository**.

Every time you push your changes, a hook generates all zone files and,
if necessary, increases serial numbers. This has been inspired by
[LuaDNS](http://www.luadns.com/).


## Pre-requisites

DNS Git has been tested with version 4.1.1 of the
[PowerDNS Authoritative Server](https://www.powerdns.com/).

DNS Git supports two PowerDNS backends: BIND and SQLite3.

You need to have Git and a recent version of Ruby (>= v2.4) installed on
your server. If you want to use the SQLite backend, you'll also need
development packages for Ruby and libsqlite3, plus a C compiler (on
Debian-based OS, `ruby-dev`, `libsqlite3-dev` and `build-essential` should
suffice).


## Installation

First, clone the repository (on the machine your PowerDNS server runs on):

```console
$ ssh root@yourserver.example.com
# git clone git://github.com/digineo/dnsgit /opt/dnsgit
# cd /opt/dnsgit
```

Then install the required libraries using bundler.

Depending on whether or not you have PowerDNS configured with
`launch=bind` or `launch=gsqlite3`, you need to execute one of these
commands:

```console
# bundle install --without=sqlite
# bundle install --with=sqlite
```

Finally, initialize a sample configuration repository:

```console
# bin/init
Please clone and update the configuration:
  git clone root@yourserver.example.com:/opt/dnsgit/data dns-config
```


## Configuration

Run these steps locally on your own machine:

```console
$ git clone root@yourserver.example.com:/opt/dnsgit/data dns-config
$ cd dns-config
```

The first thing you should do after setup is modify the contained
`config.yml` and update the values according to your PowerDNS
installation (remove `sqlite:` section for `launch=bind` or remove
`bind:` section for `launch=gsqlite3`).

Once that's done, you can update the zones.

Then push your changes back to the server.

```console
$ git add -A
$ git commit -m "my commit message"
$ git push
```

On error, your commit will be rejected.


### Examples

Take a look at the [lib/example/](lib/example/) and [tests](test/unit/)
folders.


## Development

To run tests, simply invoke `rake`.

## Debug output

To get a detailed log of what happens on a `git push`, modify
`bin/hooks/pre-receive` on the server:

```diff
 # Generate Zones
-ruby -I$basedir/lib $basedir/bin/run.rb
+DNSGIT_DEBUG=all ruby -I$basedir/lib $basedir/bin/run.rb
```

You can reduce the log amount by setting `DNSGIT_DEBUG` to a comma-separated
list of (lowercase) class names. Known log-enabled classes include:

- `bind` - for the BIND backend
- `sqlite` - for the SQLite backend
- `work` - for details in the SQLite backend
- `zone` - logs effects of your DSL files

The class names of log-enabled classes are printed in magenta in the
log output.
