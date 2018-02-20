class SyncIssueTrackerJob < ApplicationJob
  queue_as :default

  def perform(issue_tracker_id)
    issue_tracker = IssueTracker.find(issue_tracker_id)

    project_id = issue_tracker.project.id.to_s

    SyncIssuesJob.perform_now(project_id)
  end
end
