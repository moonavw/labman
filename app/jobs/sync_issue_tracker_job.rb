class SyncIssueTrackerJob < ApplicationJob
  queue_as :default

  def perform(issue_tracker_id)
    issue_tracker = IssueTracker.find(issue_tracker_id)

    project_ids = issue_tracker.team.projects.map(&:id).map(&:to_s)

    SyncIssuesJob.perform_now(*project_ids)
  end
end
