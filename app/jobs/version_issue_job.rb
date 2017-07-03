class VersionIssueJob < ApplicationJob
  queue_as :default

  def perform(version_name, *issue_ids)
    Issue.where(:id.in => issue_ids).each {|issue|
      version_issue(issue, version_name)
    }
  end

  private
  def version_issue(issue, version_name)
    if issue.release && issue.release.name == version_name
      logger.info("No need to version #{issue.named}, since it already versioned by #{issue.release.named}")
      return
    end

    prj = issue.project
    api_client = prj.issue_tracker.api_client

    r_issue = api_client.Issue.find(issue.name, {fields: 'fixVersions'})

    r_editmeta = r_issue.editmeta
    matched_version = r_editmeta['fixVersions']['allowedValues'].select {|f|
      f['name'].include?("Release #{version_name}")
    }.first

    if matched_version
      logger.info("Versioning #{issue.named} to: #{matched_version['name']}")

      r_issue.save!(fields: {fixVersions: [{name: matched_version['name']}]})

      logger.info("Versioned #{issue.named} to: #{matched_version['name']}")
    else
      logger.warn("Not found the matched version for #{issue.named}, nothing happened")
    end
  end
end
