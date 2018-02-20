class SyncCodeManagerJob < ApplicationJob
  queue_as :default

  def perform(code_manager_id)
    code_manager = CodeManager.find(code_manager_id)

    project_id = code_manager.project.id.to_s

    SyncBranchesJob.perform_now(project_id)
    SyncReleasesJob.perform_now(project_id)
    SyncMergeRequestsJob.perform_now(project_id)
  end
end
