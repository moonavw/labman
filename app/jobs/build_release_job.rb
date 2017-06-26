class BuildReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(:id.in => release_ids).each {|release|
      build_release(release)
    }
  end

  def build_release(release)
    logger.info("Building release: #{release.name}")

    prj = release.project

    SyncBranchesJob.perform_now(prj.id.to_s) unless release.branch

    release.branch.unbuild

    app = prj.apps.with_stage(:development).first
    build = Build.create(name: release.tag_name, branch: release.branch, app: app)
    RunBuildJob.perform_now(build.id.to_s)

    build.reload
    app.promote if build.status == :success
  end
end
