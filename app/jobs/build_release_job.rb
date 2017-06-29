class BuildReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(:id.in => release_ids).each {|release|
      build_release(release)
    }
  end

  def build_release(release)
    logger.info("Building #{release.named}")

    unless release.branch
      logger.error("Not found the RC branch for #{release.named}")
      return
    end

    unless release.branch.build
      logger.error("Not found the build for #{release.named}")
      return
    end

    build = release.branch.build
    RunBuildJob.perform_now(build.id.to_s)

    build.reload
    build.app.promote if build.status == :success
  end
end
