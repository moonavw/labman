class SyncBuildServerJob < ApplicationJob
  queue_as :default

  def perform(build_server_id)
    build_server = BuildServer.find(build_server_id)

    prj = build_server.project

    build_ids = prj.builds.map(&:id).map(&:to_s)
    SyncBuildStatusJob.perform_now(*build_ids)

    test_ids = prj.tests.map(&:id).map(&:to_s)
    SyncTestStatusJob.perform_now(*test_ids)
  end
end
