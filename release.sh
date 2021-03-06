#!/usr/bin/env bash
set -e

# avoid the release loop by checking if the latest commit is a release commit
readonly local last_release_commit_hash=$(git log --author="$GIT_RELEASE_BOT_NAME" --pretty=format:"%H" -1)
echo "Last $GIT_RELEASE_BOT_NAME commit: ${last_release_commit_hash}"
echo "Current commit: ${GITHUB_SHA}"
if [[ "${last_release_commit_hash}" = "${GITHUB_SHA}" ]]; then
     echo "Skipping for $GIT_RELEASE_BOT_NAME commit"
     exit 0
fi

# Filter the branch to execute the release on
readonly local branch=${GITHUB_REF##*/}
echo "Current branch: ${branch}"
if [[ -n "$RELEASE_BRANCH_NAME" && ! "${branch}" = "$RELEASE_BRANCH_NAME" ]]; then
     echo "Skipping for ${branch} branch"
     exit 0
fi

# Making sure we are on top of the branch
echo "Git checkout branch ${GITHUB_REF##*/}"
git checkout ${GITHUB_REF##*/}
echo "Git reset hard to ${GITHUB_SHA}"
git reset --hard ${GITHUB_SHA}

# This script will do a release of the artifact according to http://maven.apache.org/maven-release/maven-release-plugin/
echo "Setup git user name to '$GIT_RELEASE_BOT_NAME'"
git config --global user.name "$GIT_RELEASE_BOT_NAME";
echo "Setup git user email to '$GIT_RELEASE_BOT_EMAIL'"
git config --global user.email "$GIT_RELEASE_BOT_EMAIL";

# Setup GPG
echo "Import the GPG key"
export GPG_TTY=$(tty)
echo "$GPG_KEY" | base64 -d > private.key
gpg --batch --import ./private.key
chmod -R 777 ~/.gnupg/
ls -ahl ~/.gnupg/
rm ./private.key

echo "Override the java home as gitactions is seting up the JAVA_HOME env variable"
JAVA_HOME="/usr/local/openjdk-11/"
# Setup maven local repo
if [[ -n "$MAVEN_LOCAL_REPO_PATH" ]]; then
     MAVEN_REPO_LOCAL="-Dmaven.repo.local=$MAVEN_LOCAL_REPO_PATH"
fi

# Do the release
echo "Do mvn release:prepare with arguments $MAVEN_ARGS"
mvn $MAVEN_REPO_LOCAL -Dusername=$GITHUB_ACCESS_TOKEN release:prepare -B -Darguments="$MAVEN_ARGS"
echo "Do mvn release:perform with arguments $MAVEN_ARGS"
mvn $MAVEN_REPO_LOCAL release:perform -B -Darguments="$MAVEN_ARGS"
