#!/bin/sh
#
# Update rsync server directories with latest bundled source code
# This will update rsync to the latest snapshot OR release tarball
# available in the www service
#

. ~/.server.config || exit $?

cd `dirname $0`/..

for version in `ls -1 $SQUID_VCS_PATH | grep squid | cut -d- -f2`; do
	rm -rf tmp
	mkdir -p tmp/squid-$version

	src=""
	for type in xz bz2 gz; do
		src=`ls -1t $SQUID_WWW_PATH/content/Versions/v$version/squid-$version*.tar.$type 2>/dev/null | grep -v snapshot | head -n 1`
		! test -z "$src" && break;
	done
	test -z "$src" && echo "ERROR: could not find any XZ, BZip2, or GZip tarballs for squid-$version" && continue

	tar -C tmp/squid-$version --strip-components 1 -a -x -f $src 2>&1 |
		grep -v "Invalid empty pathname" |
		grep -v "Error exit delayed from previous errors" || true
	rsync -aO --delete tmp/squid-$version/ $SQUID_RSYNC_PATH/squid-$version/
done
rm -rf tmp
