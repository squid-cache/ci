#!/bin/sh

. ~/.server.config || exit $?

# Find latest version number
cd $SQUID_VCS_PATH
OLDVER=`ls -1t $SQUID_VCS_PATH | cut -d- -f2 | sort -h | tail -n 1`
NEWVER=$(( OLDVER + 1 ))

nuclearFallout ()
{
  # wipeout the WWW staging area
  rm -rf $SQUID_WWW_PATH/content/Versions/v$NEWVER

  # wipeout the VCS new version staging
  cd $SQUID_VCS_PATH/squid-$NEWVER &&
    git checkout master &&
      git branch -dD v$NEWVER-maintenance
  cd $SQUID_VCS_PATH &&
    rm -rf $SQUID_VCS_PATH/squid-$NEWVER
  echo ""
  echo " TODO MANUALLY destroy github squid-cache/squid branch v$NEWVER-maintenance"
  echo " TODO MANUALLY run: git fetch --all --prune"
  echo ""

  # rollback the old version to BETA status
  echo "master" >$SQUID_VCS_PATH/squid-$OLDVER/.BASE

  # wipeout VCS old version staging branches
  cd $SQUID_VCS_PATH/squid-$OLDVER
  git checkout v$OLDVER-maintenance &&
    git branch -dD v$OLDVER
  echo ""
  echo " TODO MANUALLY destroy github squid-cache/squid branch v$OLDVER"
  echo " TODO MANUALLY run: git fetch --all --prune"
  echo ""

  exit 1
}

if ! test -f $SQUID_VCS_PATH/squid-$OLDVER/.BASE ; then
  echo "ERROR: Squid-$OLDVER has already been promoted to Beta."
else
  echo " . Promoting Squid-$OLDVER to Beta Release ..."
  cd squid-$OLDVER
  git checkout `cat .BASE` &&
    git checkout -b v$OLDVER &&
    git push -u origin v$OLDVER &&
    git push -u github v$OLDVER &&
    rm .BASE || nuclearFallout
fi

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
  git checkout -b v${NEWVER}-release-prep &&
  git push -u origin v${NEWVER}-release-prep
  echo " .. update configure.ac ..."
  sed -e s/${OLDVER}.0.0-VCS/${NEWVER}.0.0-VCS/ <configure.ac >configure.ac.2 &&
    mv configure.ac.2 configure.ac &&
    git add configure.ac

  echo " .. add Release Notes ..."
  cp doc/release-notes/template.sgml doc/release-notes/release-${NEWVER}.sgml.in &&
    git add doc/release-notes/release-${NEWVER}.sgml.in

  changes=`git diff HEAD`
  if test -n "$changes" ; then
    git commit -m "${NEWVER}.0.0" &&
      git push &&
      gh pr create --repo squid-cache/squid --base master --fill ||
      (
        echo ""
        echo "MANUALLY: check and perform PR creation for v${NEWVER}-maintenance branch"
        echo ""
        # Do not take nuclear option automatically.
        # an error here is not harmful to the process.
      )
  else
    echo ""
    echo "ERROR: unexpected 'git diff HEAD' in v${NEWVER}-maintenance."
    echo "ERROR: do this commit manually and submit PR."
    echo ""
    nuclearFallout
  fi

#
## Publish WWW content
#
  echo " . Creating WWW directories for squid-$NEWVER .."
  cd $SQUID_WWW_PATH/content/Versions/

  echo " .. populating Versions/v$NEWVER/ ..."
  mkdir v$NEWVER &&
    cd v$NEWVER &&
    chmod g+w . || nuclearFallout
  for page in index.dyn ChangeLog.dyn RELEASENOTES.dyn ; do
    cp -p ../v$OLDVER/$page . || nuclearFallout
  done
  ln -s ../sig.dyn sig.dyn || nuclearFallout
  for subd in cfgman manuals ; do
    mkdir $subd || nuclearFallout
    chmod g+w $subd || nuclearFallout
  done

## TODO update the web server VCS system with the new files we just created

echo " ."
echo "."
echo ""
echo "   TODO Manual Check that http://master.squid-cache.org/Versions/v$NEWVER/ is correct"
echo ""
