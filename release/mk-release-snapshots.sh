#!/bin/sh
#
# Publish the latest development release (a.k.a. daily snapshot)
#

. ~/.server.config || exit $?

# auto-detect the latest 'major' version number
SQUID_RELEASE=`ls -1 $SQUID_VCS_PATH | cut -d- -f2 | sort -h | tail -n 1`

# Hostname of the CI server where snapshots are built
SQUID_BUILD_SERVER=build.squid-cache.org

# file Jenkins uses to assemble the list of snapshot files
outfile=HEAD.out

# arguments:
# jenkins job name
# destination directory
get_artifacts() {
	local job=$1
	local outdir=$2
	local artifactsUrl="https://$SQUID_BUILD_SERVER/job/${job}/lastSuccessfulBuild/artifact/artifacts/*zip*/artifacts.zip"
	rm -f artifacts.zip >/dev/null 2>&1
	if ! wget --quiet --ca-cert=/etc/ssl/certs/ISRG_Root_X1.pem "$artifactsUrl" ; then
		echo "Failed to download artifacts from $artifactsUrl" 1>&2
		return 1
	fi
 	rm -r artifacts >/dev/null 2>&1
 	if test -e artifacts ; then
 	    rm -r artifacts
 	    echo "Failed to cleanup stale `pwd`/artifacts" 1>&2
 	    return 1
 	fi
	if ! unzip -u -o -qq artifacts.zip ; then
		echo "Failed to extract files from ${job}:artifacts.zip" 1>&2
		rm -rf artifacts >/dev/null 2>&1
  		return 1
 	fi
	if ! test -d artifacts ; then
		echo "${job}:artifacts.zip does not contain an 'artifacts/' directory" 1>&2
		rm -d `unzip -Z1 artifacts.zip`
		rm -f artifacts.zip
		return 1
	fi
	rm artifacts.zip
	mv artifacts/* $outdir || ( rm -rf artifacts ; return 1 )
	rm -rf artifacts
	return 0
}

cd /var/tmp || exit $?

ver=$SQUID_RELEASE
get_artifacts website-tarballs-head $SQUID_WWW_PATH/content/Versions/v$ver/

ver=$(( $ver - 1 ))
get_artifacts website-tarballs-latest $SQUID_WWW_PATH/content/Versions/v$ver/

ver=$(( $ver - 1 ))
get_artifacts website-tarballs-old $SQUID_WWW_PATH/content/Versions/v$ver/
