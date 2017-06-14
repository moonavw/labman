class QueueBuildJob < ApplicationJob
  queue_as :default

  def perform(build_id)
    build = Build.find(build_id)

    logger.info("Queue the #{build.state} build: #{build.name}")

    unless build.state.pending?
      logger.warn("Skipped Queue build: #{build.name}, since it is not pending")
      return
    end

    # TODO: find the app for build if app nil
    unless build.app

    end

    # then lock the app
    if build.app
      build.app.state = :locked
      build.app.save!
      logger.info("Locked app: #{build.app.name}")
    end

    build.state = :queued

    build.save!

    logger.info("Queued build: #{build.name} -> #{build.status}")

    # TODO: schedule run build job
  end
end
