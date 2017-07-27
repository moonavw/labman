class SyncCodeManagerJob < ApplicationJob
  queue_as :default

  def perform(code_manager_id)
    code_manager = CodeManager.find(code_manager_id)

    project_ids = code_manager.team.projects.map(&:id).map(&:to_s)

    SyncBranchesJob.perform_now(*project_ids)
    SyncReleasesJob.perform_now(*project_ids)
    SyncMergeRequestsJob.perform_now(*project_ids)
  end
end
