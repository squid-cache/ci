#!/bin/sh
##

. ~/.server.config || exit $?

cd `dirname $0`/..

WWWBASE=$SQUID_WWW_PATH/content/
FTPBASE=$SQUID_FTP_PATH/

# NOTE: this maintains the FTP archive area.
# The pub/squid/ area (except checksums) is updated directly by the release pull.sh script

# TODO: This should be eliminated completely, replaced by a script which copies a new release
# to the proper places.
# Except that we need to update md5s.txt and sha1s.txt for the mirror check

for VERSION in 5 4 3.5 3.4 3.3 3.2 3.1 3.0 2.7; do
	PACKAGE=`echo "v${VERSION}" | grep -o -E "^v[0-9]+"`

	if test -d ${WWWBASE}Versions/${PACKAGE}/ -a ! -d ${FTPBASE}archive/${VERSION}; then
		mkdir ${FTPBASE}archive/${VERSION}
	fi

	# Only old series have a VERSION sub-directory
	if test -d ${WWWBASE}Versions/${PACKAGE}/${VERSION}/; then
		cd ${WWWBASE}Versions/${PACKAGE}/${VERSION}/
		# for old 3.x.y.z naming scheme.
		for f in `ls -rt1 . | grep -E "^squid-[0-9]\.[0-9]\.[0-9]+(\.[0-9]+)?(\.[a-z]|-RELEASENOTES\.)"` ; do
#			echo "COPY1: ${f} ${FTPBASE}archive/${VERSION}/"
			ln ${f} ${FTPBASE}archive/${VERSION}/ 2>/dev/null
		done
		# For old 2.x.STABLEn naming.
		for f in `ls -rt1 . | grep -E "^squid-[0-9]\.[0-9]\.((RC[0-9])|(STABLE[0-9]+)|(PRE[0-9])|(DEVEL[0-9]))(\.|-REL|-RC[0-9](\.|-REL))"` ; do
#			echo "COPY2: ${f} ${FTPBASE}archive/${VERSION}/"
			ln ${f} ${FTPBASE}archive/${VERSION}/ 2>/dev/null
		done
	else
		cd ${WWWBASE}Versions/${PACKAGE}/
		# for 4.x naming scheme.
		for f in `ls -rt1 . | grep -E "^squid-[0-9]\.[0-9]+(\.[0-9]+)?(\.[a-z]|-RELEASENOTES\.)"` ; do
#			echo "COPY1: ${f} ${FTPBASE}archive/${VERSION}/"
			ln ${f} ${FTPBASE}archive/${VERSION}/ 2>/dev/null
		done
	fi

	# Release from 2015 provide ${VERSION}-ChangeLog.txt
	if test -f ${VERSION}-ChangeLog.txt; then
#		echo "LINK1: ${VERSION}-ChangeLog.txt ${FTPBASE}archive/${VERSION}/ChangeLog.txt"
		ln ${VERSION}-ChangeLog.txt ${FTPBASE}archive/${VERSION}/ChangeLog.txt 2>/dev/null
	elif test -f ChangeLog.txt; then
#		echo "LINK2: ChangeLog.txt ${FTPBASE}archive/${VERSION}/ChangeLog.txt"
		# Release prior to 2015 provide ChangeLog.txt
		ln ChangeLog.txt ${FTPBASE}archive/${VERSION}/ChangeLog.txt 2>/dev/null
	fi
done

# Set good security...
# chmod 644 ${FTPBASE}squid/*.*


# Copy the very latest 2 release files to pub/squid
rm -f ${FTPBASE}squid/*.*
for VERSION in 5 4 3.5 3.4 3.3 3.2 3.1 3.0 2.7; do
	for TYPE in gz gz.asc bz2 bz2.asc xz xz.asc html; do
		TOCOPY=`ls -1t ${FTPBASE}archive/${VERSION}/*.${TYPE} 2>/dev/null | head -n 2 | tail -n 1`
		if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
			cp -p ${TOCOPY} ${FTPBASE}squid/
		fi
		TOCOPY=`ls -1t ${FTPBASE}archive/${VERSION}/*.${TYPE} 2>/dev/null | head -n 1`
		if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
			cp -p ${TOCOPY} ${FTPBASE}squid/ 2>/dev/null
		fi
	done
	# Copy the latest changelog as well
	TOCOPY=`ls -1t ${FTPBASE}archive/${VERSION}/ChangeLog.txt 2>/dev/null | head -n 1`
	if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
		cp -p ${TOCOPY} ${FTPBASE}squid/squid-${VERSION}-ChangeLog.txt
	fi
done

# Generate the pub/squid MD5 summary
# WAS: cd ${FTPBASE}squid; co -q mk-md5s.sh ; sh mk-md5s.sh; rcsclean -q
cd ${FTPBASE}squid/
rm -f md5s.txt.tmp
find * -name md5s.txt -prune -o -type f -print | sort | xargs md5sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >md5s.txt.tmp
chmod 644 ${FTPBASE}squid/md5s.txt.tmp
mv -f md5s.txt.tmp md5s.txt

# Generate the pub/archive MD5 summary
cd ${FTPBASE}archive/
rm -f md5s.txt.tmp
find * -name md5s.txt -prune -o -type f -print | sort | xargs md5sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >md5s.txt.tmp
chmod 644 ${FTPBASE}archive/md5s.txt.tmp
mv -f md5s.txt.tmp md5s.txt

# Generate the pub/squid SHA1 summary
cd ${FTPBASE}squid/
rm -f sha1s.txt.tmp
find * -name sha1s.txt -prune -o -type f -print | sort | xargs sha1sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >sha1s.txt.tmp
chmod 644 ${FTPBASE}squid/sha1s.txt.tmp
mv -f sha1s.txt.tmp sha1s.txt

# Generate the pub/archive SHA1 summary
cd ${FTPBASE}archive/
rm -f sha1s.txt.tmp
find * -name sha1s.txt -prune -o -type f -print | sort | xargs sha1sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >sha1s.txt.tmp
chmod 644 ${FTPBASE}archive/sha1s.txt.tmp
mv -f sha1s.txt.tmp sha1s.txt
