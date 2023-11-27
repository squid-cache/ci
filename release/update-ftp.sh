#!/bin/sh
##

# NOTE: this maintains the FTP archive area.
# The pub/squid/ area (except checksums) is updated directly by the release pull.sh script

. ~/.server.config || exit $?

for version in `ls -1 $SQUID_VCS_PATH | grep squid | cut -d- -f2`; do
	if test -d $SQUID_WWW_PATH/content/Versions/v$version/ -a ! -d $SQUID_FTP_PATH/archive/$version; then
		mkdir $SQUID_FTP_PATH/archive/$version
	fi

	cd $SQUID_WWW_PATH/content/Versions/v$version/
	for f in `ls -rt1 . | grep -E "^squid-[0-9]\.[0-9]+(\.[0-9]+)?(\.[a-z]|-RELEASENOTES\.)"` ; do
		ln ${f} $SQUID_FTP_PATH/archive/$version/ 2>/dev/null
	done

	ln $version-ChangeLog.txt $SQUID_FTP_PATH/archive/$version/ChangeLog.txt 2>/dev/null
done

# Set good security...
# chmod 644 $SQUID_FTP_PATH/squid/*.*


# Copy the very latest 2 release files to pub/squid (from ftp archive folder)
rm -f $SQUID_FTP_PATH/squid/*.*
# for each Squid-3.0+ release (some v3.x still supported by downstreams)
for version in `ls -1 $SQUID_FTP_PATH/archive | grep -E "^([3-9]|[0-9][0-9]+)"`; do
	for TYPE in gz gz.asc bz2 bz2.asc xz xz.asc html; do
		TOCOPY=`ls -1t $SQUID_FTP_PATH/archive/$version/*.${TYPE} 2>/dev/null | head -n 2 | tail -n 1`
		if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
			cp -p ${TOCOPY} $SQUID_FTP_PATH/squid/
		fi
		TOCOPY=`ls -1t $SQUID_FTP_PATH/archive/$version/*.${TYPE} 2>/dev/null | head -n 1`
		if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
			cp -p ${TOCOPY} $SQUID_FTP_PATH/squid/ 2>/dev/null
		fi
	done
	# Copy the latest changelog as well
	TOCOPY=`ls -1t $SQUID_FTP_PATH/archive/$version/ChangeLog.txt 2>/dev/null | head -n 1`
	if test "x${TOCOPY}" != "x" -a -f "${TOCOPY}"; then
		cp -p ${TOCOPY} $SQUID_FTP_PATH/squid/squid-$version-ChangeLog.txt
	fi
done

# Generate the pub/squid MD5 summary
# WAS: cd $SQUID_FTP_PATH/squid; co -q mk-md5s.sh ; sh mk-md5s.sh; rcsclean -q
cd $SQUID_FTP_PATH/squid/
rm -f md5s.txt.tmp
find * -name md5s.txt -prune -o -type f -print | sort | xargs md5sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >md5s.txt.tmp
chmod 644 $SQUID_FTP_PATH/squid/md5s.txt.tmp
mv -f md5s.txt.tmp md5s.txt

# Generate the pub/archive MD5 summary
cd $SQUID_FTP_PATH/archive/
rm -f md5s.txt.tmp
find * -name md5s.txt -prune -o -type f -print | sort | xargs md5sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >md5s.txt.tmp
chmod 644 $SQUID_FTP_PATH/archive/md5s.txt.tmp
mv -f md5s.txt.tmp md5s.txt

# Generate the pub/squid SHA1 summary
cd $SQUID_FTP_PATH/squid/
rm -f sha1s.txt.tmp
find * -name sha1s.txt -prune -o -type f -print | sort | xargs sha1sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >sha1s.txt.tmp
chmod 644 $SQUID_FTP_PATH/squid/sha1s.txt.tmp
mv -f sha1s.txt.tmp sha1s.txt

# Generate the pub/archive SHA1 summary
cd $SQUID_FTP_PATH/archive/
rm -f sha1s.txt.tmp
find * -name sha1s.txt -prune -o -type f -print | sort | xargs sha1sum | grep -v "md5s.txt" | grep -v "sha1s.txt" >sha1s.txt.tmp
chmod 644 $SQUID_FTP_PATH/archive/sha1s.txt.tmp
mv -f sha1s.txt.tmp sha1s.txt
