#!/bin/sh
#
# Update rsync server directories with latest bundled source code
# This will update rsync to the latest snapshot OR release tarball
# available in the www service
#

. ~/.server.config || exit $?

# ensure we have a clean staging directory
test -e /tmp/update-rsync.d &&
	echo "ERROR: Garbage found at /tmp/update-rsync.d" &&
	exit 1
mkdir -p /tmp/update-rsync.d

for version in `ls -1 $SQUID_VCS_PATH | grep squid | cut -d- -f2`; do

	# locate newest tarball, allow for variation in compression
	src=""
	for type in xz bz2 gz; do
		src=`ls -1t $SQUID_WWW_PATH/content/Versions/v$version/squid-$version*.tar.$type 2>/dev/null | grep -v snapshot | head -n 1`
		! test -z "$src" && break;
	done
	test -z "$src" && echo "ERROR: could not find any XZ, BZip2, or GZip tarballs for squid-$version" && continue

	# extract found tarball to staging area
	tar -C /tmp/update-rsync.d --strip-components 1 -a -x -f $src 2>&1 |
		grep -v "Invalid empty pathname" |
		grep -v "Error exit delayed from previous errors" || true

	# mirror staging area to published code
	rsync -aO --delete /tmp/update-rsync.d/ $SQUID_RSYNC_PATH/squid-$version/

	rm -rf /tmp/update-rsync.d/*
done

# POSIX requirement: do not leave garbage in /tmp
# this also helps above detection of broken automation
rm -rf /tmp/update-rsync.d
