class SyncBuildServerJob < ApplicationJob
  queue_as :default

  def perform(build_server_id)
    build_server = BuildServer.find(build_server_id)

    project_ids = build_server.team.projects.map(&:id).map(&:to_s)

    Project.where(:id.in => project_ids).each {|prj|
      build_ids = prj.builds.map(&:id).map(&:to_s)
      SyncBuildStatusJob.perform_now(*build_ids)
    }
  end
end
