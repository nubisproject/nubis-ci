#!/bin/sh

# Bootstrap the update service, oterwise, it's on a schedule, so make sure we are
# updated from boot time
wget -O /tmp/default.js http://updates.jenkins-ci.org/update-center.json
sed '1d;$d' /tmp/default.js > /tmp/default.json
curl -X POST -H "Accept: application/json" -d @/tmp/default.json http://localhost:8080/updateCenter/byId/default/postBack

# Stop jenkins for reconfiguration
service jenkins stop

# shell parse our userdata
eval `ec2metadata --user-data`

# Create the job directories
mkdir -p /var/lib/jenkins/jobs/$NUBIS_CI_NAME-integration

# Drop project configuration for jenkins
cp /etc/nubis.d/jenkins-integration-config.xml /var/lib/jenkins/jobs/$NUBIS_CI_NAME-integration/config.xml
perl -pi -e "s[%%NUBIS_GIT_REPO%%][$NUBIS_GIT_REPO]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-integration/config.xml
perl -pi -e "s[%%NUBIS_CI_NAME%%][$NUBIS_CI_NAME]g" /var/lib/jenkins/jobs/$NUBIS_CI_NAME-integration/config.xml

# XXX: We still need to create the deployment job
mkdir -p /var/lib/jenkins/jobs/$NUBIS_CI_NAME-deploy

# Make sure jenkins owns this stuff
chown -R jenkins:jenkins /var/lib/jenkins/jobs

# Finally, start jenkins for good
service jenkins start
