
## Squid Release Automation

### .server.config

Template configurtion file for the scripts found in this directory.

Copy to ~/.server.config and fill out with the appropriate values for
services provided on the server running these automation scripts.

---

## Automated Publishing Scripts

The `crontab` configuration driving this automation:
```
03 */2 * * * bin/release/mk-release-snapshots.sh
21 */2 * * * bin/release/mk-cfgman-docs.sh
23 */2 * * * bin/release/mk-langpack.sh
25 */2 * * * bin/release/mk-www-manuals.sh
```

### mk-cfgman-docs.sh

Publish the latest [Squid Configuration Guide](http://www.squid-cache.org/Doc/config/).

Fully automated ROLLING release.

### mk-langpack.sh

Publish the latest [Squid Translation Package](http://www.squid-cache.org/Versions/langpack/).

Fully automated ROLLING release.

### mk-release-series.sh

Branch and publish the next [Squid Series](https://wiki.squid-cache.org/ReleaseSchedule).

This script serves two roles:
 1. a checklist for release manager(s) on tasks required to branch a new major release series of Squid.
 2. a script to ease those tasks as much as possible.

This script is intended to be run manually with review of the changes is performed, and additional steps are required for the complete process.

### mk-www-manuals.sh

Publish the latest [Squid Tool Manuals](http://www.squid-cache.org/Doc/man/).

Fully automated ROLLING release.

---

## Automated Server Updates

The `crontab` configuration driving this automation:
```
27 */2 * * * bin/release/update-rsync.sh
```

### update-rsync.sh

Update rsync server directories with latest bundled source code.
