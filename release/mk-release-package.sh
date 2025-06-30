#!/usr/bin/env bash

set -u -o pipefail
repo=""
origin="origin"
upstream="upstream"
backfill=""
push=""
savedargs=$@
changelog_file=${changelog_file:-ChangeLog}
# sets SIGNKEY, EMAIL, GPGHOME. May set other variables
test -f "$HOME/.squidrelease.rc" && . "$HOME/.squidrelease.rc"

# args: variable and tool name. if variable is empty, bail
require() { if [ -z "$1" ]; then echo "$2 is required"; exit 1; fi }

# test for tools
SED="${SED:-`which gsed`}"; SED="${SED:-`which sed`}"; require "${SED:-}" sed
FGREP=${FGREP:-`which fgrep`}; FGREP="${FGREP:-`which fgrep`}"; require "${FGREP:-}" fgrep
GPG=${GPG:-`which gpg`}; require "${GPG:-}" gpg
GH=${GH:-`which gh`}; require "${GH:-}" gh

require "${SIGNKEY:-}" "SIGNKEY setting"
require "${EMAIL:-}" "EMAIL setting"

po2html=`which po2html`
if test -z "$po2html" ; then
    echo "cannot find po2html"
    exit 1
fi
po2txt=`which po2txt`
if test -z "$po2txt" ; then
    echo "cannot find po2txt"
    exit 1
fi

usage() {
cat <<_EOF
use:
 $0 [options] <new version> <old version>
 options:
   -R <github-repo> to use for PRs
   -o <origin>: (git) remote repository for pushing PR branches
                default "origin"
   -u <upstream>: (git) remote repository with public sources to use
                  default "upstream"
   -b : this is a backfill. Create a release for <new version> using
        preexisting tags
   -p : push, do not ask to push
   -g <path/to/gpg-trustdb>:

If no ChangeLog entry exists for the new version, prepares one
and helps prepare it for merge.

_EOF
}

# argument: a tag. Returns 0 if the tag exists, 1 if it doesn't
have_tag() {
    git tag -l "$1" | $FGREP -q "$1"
    return $?
}

have_branch() {
    git branch -l "$1" | $FGREP -q "$1"
    return $?
}

# as a side effect, set variables with timestamps.
# gets as argument a tag; if the tag exists, then
# use it as a timestamp, otherwise use the current date.
setup_release_timestamps() {
    test -n "${release_timestamp:-}" && return 0
    if have_tag $1; then
        release_timestamp=`git show --pretty=%ct --no-patch $1`
    else
        release_timestamp=`date +%s`
    fi
    release_timedate=`date -R -u -d @${release_timestamp}`
    release_date=`date -u '+%d %b %Y' -d @${release_timestamp}`
}

# argument: the files to be signed
# uses GPG, SIGNKEY, EMAIL, GPGHOME
signfiles() {
    setup_release_timestamps $new_tag
    for file; do
        size="`stat $file | awk '/Size:/ {print $2;}'`"
        md5="`md5sum -b $file | awk '{print $1;}'`"
        sha1="`sha1sum -b $file | awk '{print $1;}'`"
        sha256="`sha256sum -b $file | awk '{print $1;}'`"
        fingerprint=`$GPG --fingerprint $SIGNKEY | grep -v -E "^[up]" | grep -v -E "^$"`
        (
            cat <<EOF
File     : $file
Date     : $release_timedate
Size     : $size
MD5      : $md5
SHA1     : $sha1
SHA256   : $sha256
Key      : $SIGNKEY $EMAIL
Fingerprint: $fingerprint
Keyring  : http://www.squid-cache.org/pgp.asc
Keyserver: keyserver.ubuntu.com
EOF
        $GPG ${GPGHOME:+ --homedir $GPGHOME} --use-agent --default-key $SIGNKEY -o- -ba $file
        ) > $file.asc
    done
}

package_release() {
    # actually prep the release
    setup_release_timestamps $new_tag

    git clean -fdx
    ./bootstrap.sh
    $SED -i~ "s@${new_version}-\(VCS\|CVS\)@${new_version}@" configure.ac && rm configure.ac~
    $SED -i~ "s@${new_version}-\(VCS\|CVS\)@${new_version}@" configure && rm configure~
    $SED -i~ "s@squid_curreleasedate@${release_timestamp}@" include/version.h && rm include/version.h~
    rm -rf libltdl/config-h.in~ libltdl/configure~ .github
    # git add -f '**' # ignore .gitignore

    ./configure --silent --enable-translation
    make -j`nproc` -l`nproc` dist-all

    # prep changelog
    export new_version
    awk "/^Changes (in|to) squid-${new_version} /{flag=2} /^$/{flag=flag-1} flag>0" ${changelog_file} >$release_changelog_file
    local push_tag
    if [ -z "$backfill" ] ; then push_tag="$new_tag" ; fi
    # relevant metadata files: ChangeLog CONTRIBUTORS COPYING CREDITS README SPONSORS.list doc/release-notes/release-*.html
    signfiles squid-${new_version}.tar.*
    declare -a filelist
    filelist=()
    for f in *.tar.?? *.tar.???
    do
        filelist+=(" '${f}#Bootstrapped sources: ${f}'")
        filelist+=(" '${f}.asc#Signature for ${f}'")
    done

    pushcmd="$GH $repo release create $new_tag -F $release_changelog_file --title "v${new_version}" ${filelist[@]}"
    if [ "$push" = "yes" ] ; then
        eval $pushcmd
        echo "pushed! command:"
    else
        echo "Ready for pushing. To do it, run: "
    fi
    echo $pushcmd
}

while getopts "hR:o:u:bpg:" optchar ; do
    case "${optchar}" in
    h) usage; exit 0;;
    R) repo="-R ${OPTARG}";;
    o) origin="$OPTARG";;
    u) upstream="$OPTARG";;
    b) backfill="yes";;
    p) push="yes";;
    g) GPGHOME="$OPTARG";;
    -) break;;
    esac
done
shift $((OPTIND -1))

if [ $# -lt 2 ]; then
    usage
    exit 2
fi

new_version="$1"
old_version="$2"

new_tag=SQUID_`echo $new_version | tr . _`
old_tag=SQUID_`echo $old_version | tr . _`


current_branch=`git branch --show-current`
release_prep_branch="prep-v${new_version}"
tmp_changelog_file="ChangeLog-$new_version"
release_changelog_file="/tmp/${tmp_changelog_file}"

echo "new: $new_tag old: $old_tag"
echo "repository: $repo"

# check that old tag exists
# TODO: move to new-release only
if false &&  ! have_tag "$old_tag" ; then
    echo "could not find tag $old_tag"
    usage
    exit 2
fi

## TODO: REDO BACKFILL starting from tarball
if [ -n "$backfill" ]; then
    if ! have_tag "$new_tag" ; then
        echo "Error: backfill requested but missing tag $new_tag"
        exit 2
    fi
    git reset --hard "$new_tag"
    git clean -fdx

    # TODO: here
    package_release
    exit 0
fi

# not a backfill. Wipe tags
have_tag "$new_tag" && git tag -d "$new_tag"



# if the ChangeLog is not ready, prepare one and bail
setup_release_timestamps $new_tag
if ! fgrep -q "Changes in squid-${new_version}" ${changelog_file}; then
    if have_branch "$release_prep_branch" ; then
        git branch -D "$release_prep_branch"
        git push -d "$origin" "$release_prep_branch" || true # ignore errors
    fi
    echo "Please prepare the ChangeLog and remove this line" >>$tmp_changelog_file
    echo "Changes in squid-${new_version} (${release_date}):" >>$tmp_changelog_file
    echo "" >>$tmp_changelog_file
    git log --no-decorate --oneline ${old_tag}.. | $SED 's@^[^ ]* @	- @;s@(#[0-9]*)$@@;s@  *$@@g' >>$tmp_changelog_file
    echo >> $tmp_changelog_file
    cat ChangeLog >> $tmp_changelog_file
    mv $tmp_changelog_file ChangeLog
    ${EDITOR:-vi} ChangeLog
    git checkout -b $release_prep_branch $current_branch
    git add ChangeLog
    git commit -m "Prep for v$new_version"
    git push -d $origin $release_prep_branch
    git push $origin
    $GH $repo pr create --base $current_branch --title "Prep for v$new_version"
    git switch $current_branch

    echo
    echo "now merge the ChangeLog PR and then run again"
    echo "$0 $savedargs"
    exit 0
fi


# TODO: if have_tag $new_release, then get to that point in releasedate and
#       skip fixing changelog
# check that the release in configure.ac is what we expect it to be
if ! $FGREP -q "AC_INIT([Squid Web Proxy],[${new_version}-VCS],[https://bugs.squid-cache.org/],[squid])" configure.ac ; then
    if ! $FGREP -q "AC_INIT([Squid Web Proxy],[${old_version}-VCS],[https://bugs.squid-cache.org/],[squid])" configure.ac ; then
        echo "old version $old_version not found in configure.ac"
        exit 2
    fi
fi

# update release version in configure.ac
$SED -i~ "s@${old_version}-VCS@${new_version}-VCS@" configure.ac

git add configure.ac
git commit -m "v$new_version"
git push "$upstream"
git tag $new_tag
git push "$upstream" HEAD $new_tag

package_release
