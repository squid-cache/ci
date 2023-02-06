#!/bin/sh
#
# Automatically publish Squid documentation manuals
# from latest releases of each version.
#

test -e ~/.server.config && . ~/.server.config || exit 1

cd ${SQUID_WWW_PATH}/content/Versions/

for v in `ls -1`; do
	if test "$v" = "." -o "$v" = ".." -o "$v" = "CVS" -o "$v" = "langpack" -o ! -d $v; then
		continue;
	fi

	# Manuals only added in v3 and later, but v3 has sub-versions
	# avoid complications by only updating v4 and later documentation
	if test "$v" = "v1" -o "$v" = "v2" -o "$v" = "v3"; then
		continue;
	fi

	cd $v
	version=`echo "$v" | sed s/v//`

	# Expand the cfgman and manuals tarballs into their respective directories
	cfgmantar=`ls -t1 squid-${version}.*-*-cfgman.tar.gz | grep -v snapshot | head -n 1`
	cd cfgman && tar -xzf ../${cfgmantar}
	cd ..
	mantar=`ls -t1 squid-${version}.*-*-manuals.tar.gz | grep -v snapshot | head -n 1`
	cd manuals && tar -xzf ../${mantar}
	cd ..

	# Map the Manuals HTML to squid-cache.org .dyn pages
	echo "<h2>Squid Tools and Helper Manual Pages</h2>" >manuals/index.dyn.tmp
	echo "<ul>" >>manuals/index.dyn.tmp
	for f in `ls -1 manuals/*.html` ; do
		fn=`echo "${f}" | sed s/.1.html// | sed s/.8.html//`
		fl=`echo "${fn}" | sed s%manuals/%%`
		cat ${f} | sed \
			-e 's%<!.*%%' \
			-e 's%.http://www.w3.org/TR/html4/loose.dtd.*%%' \
			-e 's%<meta.*%%' \
			-e 's%<title.*%%' \
			-e 's%<style.*%%' -e 's%</style>%%' \
			-e 's%^\ \ .*margin-top.*%%' \
			-e 's%<head>%%' -e 's%</head>%%' \
			-e 's%<body>%%' -e 's%</body>%%' \
			-e 's%<html>%%' -e 's%</html>%%' \
			-e 's%<br>%<br\ />%' \
			-e 's%<hr>%<hr\ />%' \
				>${fn}.dyn.tmp
		mv -f ${fn}.dyn.tmp ${fn}.dyn
		touch -r ${f} ${fn}.dyn
		ln -s ${fl}.html ${fn} 2>/dev/null || true
		echo "<li><a href=\"${fn}.html\">${fn}</a></li>" | sed -e 's%manuals/%%g' >>manuals/index.dyn.tmp
	done
	echo "</ul>" >>manuals/index.dyn.tmp
	mv -f manuals/index.dyn.tmp manuals/index.dyn

	# leave the sub-version directory
	cd ..
done
