class BuildReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(:id.in => release_ids).each {|release|
      build_release(release)
    }
  end

  def build_release(release)
    logger.info("Building #{release.named}")

    prj = release.project

    SyncBranchesJob.perform_now(prj.id.to_s) unless release.branch

    build = release.rebuild
    RunBuildJob.perform_now(build.id.to_s)

    build.reload
    app.promote if build.status == :success
  end
end
