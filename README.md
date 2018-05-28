# Labman
Integrated CI dashboard, it connects to Gitlab, Jenkins, Heroku, and JIRA, to provide all info in one place, and the action buttons for CI workflow.

## Features
- Projects
	- each project has the Gitlab, Jenkins, Heroku and JIRA behind, need config for their connections
- User & Access
	- user could be in multiple projects
	- anonymous has readonly access to non-private project 
	- members in the project has operation access to the non-protected items: e.g. feature branch build & test
	- masters in the project has operation access to the protected items: e.g. RC branch bump, build & test
	- masters in the project has operation access to set/unset master in members list on project page
- Apps
	- all apps and pipelines from Heroku
	- show all app config and version
	- show all related builds and promotions
	- project members could pick an app to deploy the branch build for demo etc, and locked the app from other branch builds
	- the app will be unlocked automatically when the related JIRA issue done (resolved/closed/done/ready for test/deployed...) or the branch deleted (e.g. remove source branch when merge request accepted)
	- when have a RC build, it would automatically arrive next stage by promotion
	- project members could promote app in development stage to staging stage if any app in staging stage not promoted from it yet
	- project masters could promote app in staging stage to production stage if any app in production stage not promoted from it yet
- Branches
	- all branches from gitlab repository
	- show all outgoing/incoming merges for branch
	- show the app of the branch deployed to
	- project members could build the branch to deploy to app
	- project members could test the branch with local app, or with app of build if branch has build
- Merge Requests
	- show all merge requests for current working releases with status
	- project masters could approve the merge request if it reviewed (pass code review and build check), then CI will accept the merge request automatically
	- transit the related JIRA issue status to complete/resolve/done and set fix version when merge request accepted
- Builds
	- show all builds with status
	- the build will automatically rerun when the branch has new commit (except: the RC build is run by demand)
- Tests
	- show all tests with status
- Issues
	- show all JIRA issues in current sprint with status
	- show related build, related release, and related merge request for the JIRA issue
- Releases
	- show all releases (milestones defined in gitlab) with status, due date, last version tag
	- show related JIRA issues, RC branch, RC build for release
	- project masters could bump release: create RC or patch RC
	- when bumped, it auto build release and deploy to specified app in pipeline, also promote to next stage in pipeline. And transit issue status to "Ready for test/Deployed..."
	- auto configure the app config for each release build
	- project masters could publish the release as the RC ready to release
	- when a Release closed, the RC branch and outdated tags will be deleted from gitlab, only keep the last tag

## Constants
there are some constants defined in code as convention
```
# Release
BRANCH_PREFIX = 'release/v'
BUILD_NAME = 'rc'
PUBLISH_TAG = 'latest'
```

## Configuration
various config required for the connections to external systems and internal workflow.
all in YAML format.

### Code Manager
- Gitlab CE v8+ config
```
endpoint: <your-gitlab-api-endpoint>
private_token: <your-gitlab-token>
```

### Build Server
- Jenkins v2+ config
```
server_ip: <your-jenkins-server-ip>
server_port: <your-jenkins-server-port>
username: <your-jenkins-user>
password: <your-jenkins-pwd>
ssl: true|false
```

### App Platform
- Heroku config
```
oauth_token: <your-heroku-token>
```

### Issue Tracker
- JIRA config
```
username: <your-jira-user>
password: <your-jira-pwd>
site: <your-jira-website>
context_path: ''
auth_type: basic
```

### Project
```
GITLAB_PROJECT: <your-gitlab-project-full-name>
JENKINS_PROJECT:
  BUILD: <your-jenkins-job-template-for-build-branch>
  TEST: <your-jenkins-job-template-for-test-branch>
  RC: <your-jenkins-job-for-bump-rc>
  RC_PATCH: <your-jenkins-job-for-bump-rc-patch>
  ACCEPT_MERGE_REQUEST: <your-jenkins-job-for-accepting-merge-request>
HEROKU_PROJECT: <your-heroku-app-prefix-name>
MERGE_REQUEST:
  APPROVAL: <min-number-of-thumbup-to-approve-merge-request>
APP:
  CONFIG:
   <your-app-default-config-key>: <your-app-default-config-value>
   ...
  VERSION_API: <your-app-version-api-url, support-string-template-with-config-keys>
BUILD:
  CONFIG:
   <your-build-default-app-config-key>: <your-build-default-app-config-value, support-eval-instance-self>
   ...
TEST:
  CONFIG:
   <your-test-default-config-key>: <your-test-default-config-value, support-eval-instance-self>
   ...
RELEASE:
  BUILD:
    APP: <your-rc-build-app-name>
    CONFIG:
     <your-build-app-config-key>: <your-build-app-config-value, support-eval-instance-self>
     ...
JIRA_PROJECT: <your-jira-project-key>
JIRA_BOARD: <your-jira-agile-board-id>
JIRA_ISSUE_STATUS:
  TO_DO:
  - <your-jira-issue-status-as-to-do>
  ...
  IN_PROGRESS:
  - <your-jira-issue-status-as-in-progress>
  ...
  DONE:
  - <your-jira-issue-status-as-done>
  ...
JIRA_ISSUE_TRANSITIONS:
  ACCEPT_MERGE_REQUEST:
  - <your-jira-issue-status-to-transit-when-merge-request-accepted>
  ...
  BUILD_RELEASE:
  - <your-jira-issue-status-to-transit-when-release-built>
  ...
```

## Services
all the long running activities for Gitlab, Jenkins, Heroku, JIRA are enqueued to redis, then performed by sidekiq.

### Build Server
kick Jenkins for:

- run branch build by copying Jenkins job from a specified job, the Jenkins job must set the build displayName as a version: e.g. displayName = '2.22.1'
- create RC branch with bumped major/minor version, the Jenkins job must set the build displayName as the bumped version
- patch RC branch as bumping patch version, the Jenkins job must set the build displayName as the bumped version
- accept merge request

### Sync Code Manager
sync from Gitlab:

- branches
- merge requests
- releases (by milestones, tags)

scheduled via set interval for a CodeManager in cron format:

- every 10 min:
```*/10 * * * *```

### Sync Issue Tracker
sync from JIRA:

- issues (by agile board, sprint)

scheduled via set interval for a IssueTracker in cron format:

- every 10 min:
```*/10 * * * *```

### Sync App Platform
sync from Heroku:

- apps
- pipelines

scheduled via set interval for a AppPlatform in cron format:

- every 30 min:
```*/30 * * * *```

## Deployment
It is a dockerized app, docker-compose with redis and mongo.

external volume for database is required to avoid data loss, that need to be created first:

```docker volume create dbstore```

OR with volume mounting to local file system on non-windows (mongo has issue with volume mounting to windows file system)

```docker volume create dbstore --opt type=none --opt device=<db_path> --opt o=bind```

then run with specified publish port for app:

```APP_PORT=9080 docker-compose up -d```

OR run with default publish port 8000 for app:

```docker-compose up -d```

## Database
it needs a default admin when fresh deployed:

```docker exec -e "ADMIN_EMAIL=<email>" -e "ADMIN_PASSWORD=<password>" $(docker-compose ps -q app) ./bin/rails db:seed```

or with default value for ADMIN_EMAIL (see docker-compose.yml) and ADMIN_PASSWORD (see db/seeds.rb)

```docker-compose exec app ./bin/rails db:seed```
