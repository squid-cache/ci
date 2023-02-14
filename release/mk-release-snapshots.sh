#!/bin/sh
#
# Publish Alpha releases (a.k.a. daily snapshot)
#

. ~/.server.config || exit $?

# auto-detect the latest 'major' version number
SQUID_RELEASE=`ls -1 $SQUID_VCS_PATH | cut -d- -f2 | sort -h | tail -n 1`

# file Jenkins uses to assemble the list of snapshot files
outfile=HEAD

ver=$SQUID_RELEASE
(rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-head/squid-${ver}* $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null &&
rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-head/${outfile}.out $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null
) ||
	echo "rsync pull squid-$ver code snapshots from BuildFarm failed"

ver=$(( $ver - 1 ))
(rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-latest/squid-${ver}* $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null &&
rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-latest/${outfile}.out $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null ) ||
	echo "rsync pull squid-$ver code snapshots from BuildFarm failed"

ver=$(( $ver - 1 ))
(rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-old/squid-${ver}* $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null &&
rsync -rcz --delete-delay rsync://$SQUID_CI_SERVER/snapshots-old/${outfile}.out $SQUID_WWW_PATH/content/Versions/v$ver/ 2>/dev/null ) ||
	echo "rsync pull squid-$ver code snapshots from BuildFarm failed"