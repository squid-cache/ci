#!/bin/sh
#
# Automatically publish 'langpack' releases.
#
#  There are tests later to prevent the langpack files being altered
#  if the langpack content has not actually changed.
#
#  To force a build with todays snapshot pass "--force" as the first parameter
#

test -e ~/.server.config && . ~/.server.config || exit 1

# Location where the langpack files are published
filedir=$SQUID_WWW_PATH/content/Versions/langpack

# auto-detect the latest 'major' version number
SQUID_RELEASE=`ls -1 $SQUID_VCS_PATH | cut -d- -f2 | sort -h`

# Location of the latest versions repository checkout
vcsdir="${SQUID_VCS_PATH}squid-${SQUID_RELEASE}"
if ! test -d $vcsdir ; then
	echo "ERROR: failed to locate Squid VCS"
	exit 1
fi

cd $filedir

# find a Squid version which provides a langpack
# should be the latest one with a release.
getver () {
	ls -1t .. 2>/dev/null | grep -e "^v" | sed -e 's/v//' | sort -ur |
	while read V; do
		lp=`(ls -1t ../v${V}/ 2>/dev/null | grep langpack.tar.gz | head -n 1 )|| true`
		if test "x${lp}" != "x"; then
			echo "${V}"
			exit 0;
		fi
	done
}
ver=`getver`
test "x${ver}" = "x" && echo "WARNING: no langpacks found"
test "x${ver}" = "x" && exit 1

snapshot=`ls -1t ../v${ver}/squid-${ver}*-langpack.tar.gz | head -n 1`
snapshot=`basename $snapshot -langpack.tar.gz`
#echo "Build langpack from: ${snapshot}"
dateA=`echo $snapshot | sed -e 's/-r.*//' | sed -e 's/.*-//'`
date=`date +"%b %e %G" --date="${dateA}"`
snapdate=`echo "${snapshot}" | sed s/-/:/g | cut -d: -f3`

# We have had a number of langpack construction failures
#  with the translated files failing to distribute.
# If that happens we get a very small bundle of just templates (~12KB)
#  as of today the bundle should be just toping 250 KB when full.
#  require a minimum of half that.
#
size=`ls -l ../v${ver}/${snapshot}-langpack.tar.gz | awk '{print $5}'`
if test ${size} -lt 102400 ; then
	echo "ERROR: snapshot langpack too small to be full (${size} bytes < 100 KB)"
	exit 1
fi
kbytes=$((size/1024))
# echo "DEBUG: v${ver}/${snapshot}.tar.gz = ${size} :: ${kbytes} "

# check and see if the language files have actually been changed since last time we grabbed a snapshot...
oldchange=`cat .lastchange`
# git only works when run within a repo, so go there for the timestamp lookup
cd $vcsdir
lastchange=`git log -n 1 --since "${oldchange}" --date=iso errors/ | grep "Date:" | sed s/Date:\ *//`
cd $filedir

if test "$1" = "--force" ; then
  echo "LAST CHANGED: $lastchange"
  echo "Forcing a rebuild anyway."
else
  if test "$oldchange" = "$lastchange" -a "x$oldchange" != "x" -o "x$lastchange" = "x"; then
#    echo "Squid Langpack not changed since $oldchange"
    exit 0
  fi
  echo "Squid Langpack updated $lastchange"
fi

# Mark the new change timestamp early to prevent parallel execution if the update is slow.
echo "$lastchange" >.lastchange.new
mv .lastchange.new .lastchange

# Replace the old snapshot with our new one.
rm -f squid-langpack-*.tar.gz
cp ../v${ver}/${snapshot}-langpack.tar.gz ./squid-langpack-$snapdate.tar.gz
rm -f squid-langpack-*.tar.gz.md5
if ! test -f ../v${ver}/${snapshot}-langpack.tar.gz.md5; then
	md5sum ../v${ver}/${snapshot}-langpack.tar.gz >../v${ver}/${snapshot}-langpack.tar.gz.md5
fi
cp ../v${ver}/${snapshot}-langpack.tar.gz.md5 ./squid-langpack-$snapdate.tar.gz.md5

# Summarize the number and names of languages available.
cp squid-langpack-$snapdate.tar.gz ./langpack.tar.gz &&
	gunzip langpack.tar.gz
bcount=`tar -tf ./langpack.tar | grep -v "templates" | grep -c "ERR_ACCESS_DENIED"`
langs=`tar -tf ./langpack.tar | grep "ERR_ACCESS_DENIED" | grep -v "templates" | sed s/\\\..//g | sed s/.ERR_ACCESS_DENIED//g | grep -E "^[a-z\-]*$"`

# list the new coded names with their full human name, one per line.
echo "">list.txt
for gl in $langs ; do
	(
		lng=`echo "$gl" | sed s/\-.*//g`
		alphabet=`echo "$gl" | sed s/[a-z]*// | sed s/\-//`
		(grep -E "^$lng " iso639.txt || echo -n "$lng") | sed s/$lng/\($lng\)/
                # Specials not listed in ISO-639-1 (usually from ISO-639 ammendments)
		case $alphabet in
		"br") echo -n " Brazillian "; ;;
		"cyrl") echo -n " Cyrillic "; ;;
		"hans") echo -n " Simplified "; ;;
		"hant") echo -n " Traditional "; ;;
		"latn") echo -n " Latin "; ;;
		*) echo -n " $alphabet "; ;;
		esac
	) >>list.txt
done
langsFULL=`cat list.txt`

# count the dialect aliases.
# Since we can't check the tarball content, use the local repository files...
dialects=`cat ${vcsdir}/errors/aliases | while read base alia ; do
		test "x$base" != "x##" && echo "${alia}"
	done`
acount=`echo "${dialects}" | wc -w | sed s/\ //g`

# Cleanup temporary files
rm -f ./aliases ./langpack.tar

# Total language variants presentable.
count=$(( bcount + acount ))

# Update the website
rm -f index.dyn.new
cat index.tmpl | perl -p -e "
	s/\@SNAPHEAD\@/${snapshot}.tar.gz/g;
	s/\@SNAPSHOT\@/squid-langpack-${snapdate}/g;
	s/\@DATE\@/$date/g;
	s/\@COUNT\@/$count/g;
	s/\@KBYTES\@/$kbytes/g;
	s/\@BCOUNT\@/$bcount/g;
	s/\@NAMES\@/$langsFULL/g;
	s/\@ACOUNT\@/$acount/g;
	s/\@ALIASES\@/$dialects/g;
" >index.dyn.new
chmod a=r index.dyn.new
mv -f index.dyn.new index.dyn
