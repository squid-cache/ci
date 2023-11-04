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
	if ! wget --quiet --ca-cert=/etc/ssl/certs/ISRG_Root_X1.pem "$artifactsUrl"; then
		echo "could not download artifacts from $artifactsUrl"
		return 1
	fi
	unzip -qq artifacts.zip
	if [ ! -d artifacts ]; then
		echo "${job}:artifacts.zip does not contain a subdirectory"
		rm -d `unzip -Z1 artifacts.zip`
		rm -f artifacts.zip
		return 1
	fi
	mv artifacts/* $outdir
	rmdir artifacts
	rm artifacts.zip
	return 0
}

cd /var/tmp || exit $?

ver=$SQUID_RELEASE
get_artifacts website-tarballs-head $SQUID_WWW_PATH/content/Versions/v$ver/

ver=$(( $ver - 1 ))
get_artifacts website-tarballs-latest $SQUID_WWW_PATH/content/Versions/v$ver/

ver=$(( $ver - 1 ))
get_artifacts website-tarballs-old $SQUID_WWW_PATH/content/Versions/v$ver/
