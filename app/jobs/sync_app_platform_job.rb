class SyncAppPlatformJob < ApplicationJob
  queue_as :default

  def perform(app_platform_id)
    app_platform = AppPlatform.find(app_platform_id)

    project_ids = app_platform.team.projects.map(&:id).map(&:to_s)

    SyncAppsJob.perform_now(*project_ids)
    SyncPipelinesJob.perform_now(*project_ids)
  end
end
