# DNS Git

[![CircleCI](https://circleci.com/gh/digineo/dnsgit.svg?style=svg)](https://circleci.com/gh/digineo/dnsgit)

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
# git clone git://github.com/digineo/dnsgit /opt/dnsgit
# cd /opt/dnsgit
```

Depending on whether or not you have PowerDNS configured with
`launch=bind` or `launch=gsqlite3`, you need to execute one of these
commands:

```console
# bundle install --without=sqlite
# bundle install --with=sqlite
```

(Please note that sqlite requires building a native Ruby extension. Therefore
you need to have `libsqlite3-dev`, `ruby-dev` and a C compiler installed.)

Finally, generate a sample configuration.

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

Take a look at the [lib/example/](https://github.com/digineo/dnsgit/tree/master/lib/example)
folder and the [tests](https://github.com/digineo/dnsgit/tree/master/tests/zone_test.rb).


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
