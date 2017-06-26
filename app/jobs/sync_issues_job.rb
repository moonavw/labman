class SyncIssuesJob < ApplicationJob
  queue_as :default

  def perform(*project_ids)
    unless project_ids.present?
      logger.info('Schedule jobs for all projects')
      Project.each {|prj|
        SyncIssuesJob.perform_later(prj.id.to_s) if prj.issue_tracker && prj.config
      }
      return
    end

    Project.where(:id.in => project_ids).each {|prj|
      sync_issues(prj)
    }
  end

  private
  def sync_issues(prj)
    logger.info("Syncing issues for project: #{prj.name}")

    api_client = prj.issue_tracker.api_client

    resp = api_client.Agile.get_sprints(prj.config['JIRA_BOARD'], {state: 'active'})
    cur_sprint = resp['values'].last

    logger.info("Syncing issues from current active sprint: #{cur_sprint['name']}")

    resp = api_client.Agile.get_sprint_issues(cur_sprint['id'], {fields: 'status,fixVersions', maxResults: 100})

    issues = resp['issues'].map {|d|
      issue = prj.issues.find_or_initialize_by(name: d['key'])

      case d['fields']['status']['name']
        when 'Reviewed', 'To Do', /Open/i
          issue.state = :to_do
        when /In Progress/i
          issue.state = :in_progress
        when 'Done', 'Closed', 'Cancelled', /Complete/i, /Deploy/i
          issue.state = :done
          issue.unbuild
        else
          # do not change issue state
      end

      fix_version = d['fields']['fixVersions'].map {|f|
        f['name']
      }.join(', ')

      issue.release = issue.project.releases.select {|el|
        fix_version.include?(el.name)
      }.first

      if issue.save
        issue.release.work_in_progress if issue.release
        logger.info("Synced issue: #{issue.name}")
      else
        logger.error("Failed sync issue: #{issue.name}")
        logger.error(issue.errors.messages)
      end

      issue
    }

    logger.info("Synced #{issues.count} issues")

    synced_ids = issues.map(&:id)
    orphans = prj.issues.destroy_all(:id.nin => synced_ids)

    logger.warn("Pruned #{orphans} issues")
  end
end
