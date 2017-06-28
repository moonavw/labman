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

    unless release.branch
      SyncBranchesJob.perform_now(prj.id.to_s)
      release.reload
    end

    branch = release.branch
    branch.unbuild

    app = prj.apps.with_stage(:development).first

    build = Build.create(name: release.tag_name, branch: branch, app: app)
    RunBuildJob.perform_now(build.id.to_s)

    build.reload
    app.promote if build.status == :success
  end
end
