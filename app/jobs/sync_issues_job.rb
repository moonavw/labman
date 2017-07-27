class SyncIssuesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    Project.where(:id.in => project_ids).each {|prj|
      sync_issues(prj)
    }
  end

  private
  def sync_issues(prj)
    logger.info("Syncing issues for #{prj.named}")

    issue_tracker = prj.issue_tracker

    resp = issue_tracker.api_client.Agile.get_sprints(prj.config[:JIRA_BOARD], {state: 'active'})
    cur_sprint = resp['values'].select {|d| d['originBoardId'] == prj.config[:JIRA_BOARD]}.last

    logger.info("From current active sprint: #{cur_sprint['name']}")

    issues = Issue.state.values.map {|value|
      sync_issues_by_state(prj, cur_sprint['id'], value)
    }.reduce(&:+)

    logger.info("Total Synced #{issues.count} issues")

    synced_ids = issues.map(&:id)
    orphans = prj.issues.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} issues")
  end

  def sync_issues_by_state(prj, sprint_id, issue_state)
    logger.info("Syncing #{issue_state} issues for #{prj.named}")

    issue_tracker = prj.issue_tracker

    jql_params = {
        project: prj.config[:JIRA_PROJECT],
        sprint: sprint_id,
        status: prj.config[:JIRA_ISSUE_STATUS][issue_state.to_s.upcase].join('", "')
    }

    jql_template = 'project = %{project} AND status in ("%{status}") AND Sprint = %{sprint}'
    jql = jql_template % jql_params

    logger.info("Search issues with the jql: #{jql}")

    # resp = issue_tracker.api_client.Agile.get_sprint_issues(sprint_id, {fields: 'status,fixVersions', maxResults: 150})
    resp = issue_tracker.api_client.Issue.jql(jql, {fields: %w(fixVersions), maxResults: 100})

    issues = resp.map {|d|
      issue = prj.issues.find_or_initialize_by(name: d.key)
      issue.state = issue_state
      issue.unbuild if issue.state.done?

      fix_version = d.fields['fixVersions'].map {|f|
        f['name']
      }.join(', ')

      issue.release = issue.project.releases.select {|el|
        fix_version.include?(el.name)
      }.first

      url_params = {
          site: prj.issue_tracker.config[:site].chomp('/'),
          key: issue.name
      }
      issue.url = '%{site}/browse/%{key}' % url_params

      if issue.save
        issue.release.work_in_progress if issue.release
        logger.info("Synced #{issue.named}")
      else
        logger.error("Failed sync #{issue.named}")
        logger.error(issue.errors.messages)
      end

      issue
    }

    logger.info("Synced #{issues.count} #{issue_state} issues")

    issues
  end
end
