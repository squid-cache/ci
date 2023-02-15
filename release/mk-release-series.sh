#!/bin/sh

. ~/.server.config || exit $?

# Find latest version number
cd $SQUID_VCS_PATH
OLDVER=`ls -1t $SQUID_VCS_PATH | cut -d- -f2 | sort -h | tail -n 1`
if ! test -f $SQUID_VCS_PATH/squid-$OLDVER/.BASE ; then
  echo "ERROR: Squid-$OLDVER has already been promoted to Beta."
else
  echo " . Promoting Squid-$OLDVER to Beta Release ..."
  cd squid-$OLDVER
  git checkout github/`cat .BASE` || exit 1
  git push -u origin v$OLDVER
  git push -u github v$OLDVER
  rm .BASE
fi

NEWVER=$(( OLDVER + 1 ))
if test -d $SQUID_VCS_PATH/squid-$NEWVER ; then
  echo "ERROR: Squid-$NEWVER already exists."
  exit 1
else
  echo " . Creating Squid-$NEWVER development release series ..."
  cd $SQUID_VCS_PATH
  git clone git@github.com:squidadm/squid.git squid-$NEWVER
  cd squid-$NEWVER
  git remote add github git@github.com:squid-cache/squid.git
  echo "master" >.BASE
  ln -s $SQUID_VCS_PATH/gitignore $SQUID_VCS_PATH/squid-$NEWVER/.git/info/exclude

  echo " .. Creating maintenance branches ..."
  git checkout -b v${NEWVER}-maintenance &&
  git push -u origin v${NEWVER}-maintenance
fi

#
## Update "master" branch code
#
  cd $SQUID_VCS_PATH/squid-$NEWVER
  echo " .. update configure.ac ..."
  git checkout v${NEWVER}-maintenance
  sed -e s/${OLDVER}.0.0-VCS/${NEWVER}.0.0-VCS/ <configure.ac >configure.ac.2 &&
    mv configure.ac.2 configure.ac &&
    git add configure.ac

  echo " .. add Release Notes ..."
  cp doc/release-notes/template.sgml doc/release-notes/release-${NEWVER}.sgml.in &&
    git add doc/release-notes/release-${NEWVER}.sgml.in

  if `git diff HEAD` ; then
    git commit -m "Branch ${NEWVER}.0.0"
    git push
    # github PR created by maintenance automation
  fi

#
## Publich RSYNC
#
  echo " . Creating RSYNC share directory for squid-$NEWVER .."
  mkdir $SQUID_RSYNC_PATH/squid-$NEWVER
  # content generated by snapshot automation

#
## Publish WWW content
#
  echo " . Creating WWW directories for squid-$NEWVER .."
  cd $SQUID_WWW_PATH/content/Versions/

  echo " .. populating Versions/v$NEWVER/ ..."
  mkdir v$NEWVER
  cd v$NEWVER
  chmod g+w .
  for page in index.dyn ChangeLog.dyn RELEASENOTES.dyn CONTRIBUTORS.txt ; do
    cp -p ../v$OLDVER/$page .
  done
  ln -s ../sig.dyn sig.dyn
  for subd in cfgman manuals changesets ; do
    mkdir $subd || /bin/true
    chmod g+w $subd
  done

  echo " .. populating Versions/v$NEWVER/changesets/ ..."
  cd changesets/
  echo "Squid $NEWVER" >.version
  for page in .lastrevno .lastupdate ; do
    cp -p ../../v$OLDVER/changesets/$page . || /bin/true
  done
## TODO move these scripts to CI/release or drop
  ln -s /home/squidadm/bin/update-patches-git .update
  ln -s /home/squidadm/bin/maint-group-patches .group
  ln -s /home/squidadm/bin/maint-merged-patches .merged
  ln -s /home/squidadm/bin/maint-nomerge-patches .nomerge
   ./.update

## TODO update the web server VCS system with the new files we just created

echo " ."
echo "."
echo ""
echo "   TODO Manual Check that http://master.squid-cache.org/Versions/v$NEWVER/ is correct"
echo ""
echo "   TODO Manual update of Versions/index.dyn table"
echo ""
