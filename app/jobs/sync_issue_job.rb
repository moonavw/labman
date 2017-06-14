class SyncIssueJob < ApplicationJob
  queue_as :default

  def perform(issue_id)
    issue = Issue.find(issue_id)

    logger.info("Syncing issue: #{issue.name}")


    resp = issue.project.issue_tracker.api_client_issue.find(issue.name, {fields: 'status,fixVersions'})
    logger.debug(resp.fields.inspect)

    case resp.fields['status']['name']
      when 'Reviewed', 'To Do', /Open/i
        issue.state = :todo
      when /In Progress/i
        issue.state = :in_progress
      when 'Done', 'Closed', /Complete/i
        issue.state = :done
      else
        # do not change issue state
    end

    fix_version = resp.fields['fixVersions'].map {|f|
      f['name']
    }.join(', ')

    issue.release  = issue.project.releases.select{|el|
      fix_version.include?(el.name)
    }.first

    issue.save!

    logger.info("Synced issue: #{issue.name}")

  end
end
