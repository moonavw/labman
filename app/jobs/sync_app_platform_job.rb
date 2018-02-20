class SyncAppPlatformJob < ApplicationJob
  queue_as :default

  def perform(app_platform_id)
    app_platform = AppPlatform.find(app_platform_id)

    project_id = app_platform.project.id.to_s

    SyncAppsJob.perform_now(project_id)
    SyncPipelinesJob.perform_now(project_id)
  end
end
