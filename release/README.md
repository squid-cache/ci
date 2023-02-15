
## Squid Release Automation

### .server.config

Template configurtion file for the scripts found in this directory.

Copy to ~/.server.config and fill out with the appropriate values for
services provided on the server running these automation scripts.

### mk-cfgman-docs.sh

Publish the latest [Squid Configuration Guide](http://www.squid-cache.org/Doc/config/).

### mk-langpack.sh

Publish the latest [Squid Translation Package](http://www.squid-cache.org/Versions/langpack/).

### mk-release-series.sh

Branch and publish the next [Squid Series](https://wiki.squid-cache.org/ReleaseSchedule).

### mk-release-snapshots.sh

Publish the latest [Squid Development Release](https://wiki.squid-cache.org/DeveloperResources/ReleaseProcess#development-release).

### mk-www-manuals.sh

Publish the latest [Squid Tool Manuals](http://www.squid-cache.org/Doc/man/).

### update-rsync.sh

Update rsync server directories with latest bundled source code.
