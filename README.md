# DNS Git

Run your own DNS servers and manage your zones easily with Git.

This piece of **free** software gives you the ability to describe your zone
files in a **simple DSL** (Domain Specific Language) with **templates** and
store everything in a **Git repository**.

Every time you push your changes, a hook generates all zone files and increases
serial numbers, if necessary. We have been inspired by [LuaDNS](http://www.luadns.com/).

DNS Git has been tested with:
* [PowerDNS](https://www.powerdns.com/)

## Installation

Please ensure your have Git and a current version of Ruby (at least 2.0) installed.
Then clone the repository and install the required libraries using bundler.

	git clone git://github.com/digineo/dnsgit /opt/dnsgit
	cd /opt/dnsgit
	bundle install

Finally, just generate a sample configuration.

	bin/init


## Configuration

Run these steps locally on your own machine:

	git clone ssh://root@your-server/opt/dnsgit/data dns-config
	cd dns-config

... do some changes ...

	git add -A
	git commit -m "my commit message"
	git push

### Examples

Take a look at the [/lib/example](https://github.com/digineo/dnsgit/tree/master/lib/example)
folder and the [tests](https://github.com/digineo/dnsgit/tree/master/tests/zone_test.rb).
