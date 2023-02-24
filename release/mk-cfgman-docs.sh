#!/bin/sh
#
# Automatically generate cross-version squid.conf documentation
# based on files published by mk-www-manuals.sh
#

. ~/.server.config || exit $?

# Known Bug:
#  Does not remove references to directives dropped. This is
#  an issue for branch 'master' directive erasure.

for version in `ls -1 $SQUID_VCS_PATH | grep squid | cut -d- -f2`; do

	! test -d $SQUID_WWW_PATH/content/Versions/$version/cfgman && continue

	for directive in $SQUID_WWW_PATH/content/Versions/$version/cfgman/*.html; do
		directive=`basename $directive .html`

		test "x$directive" = "xindex" && continue
		test "x$directive" = "xindex_all" && continue
		test "x$directive" = "x*" && continue

		if ! test -d $directive ; then
			echo "Updating $version docs for $directive"
			mkdir $SQUID_WWW_PATH/content/Doc/config/$directive
			ln -s ../template.dyn $SQUID_WWW_PATH/content/Doc/config/$directive/index.dyn
		else
			touch -c $SQUID_WWW_PATH/content/Doc/config/$directive/index.dyn
		fi
	done
done
