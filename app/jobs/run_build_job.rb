class RunBuildJob < ApplicationJob
  queue_as :default

  def perform(build_id)
    build = Build.find(build_id)

    logger.info("Run the #{build.state} build: #{build.name}")

    unless build.state.queued?
      logger.warn("Skipped Run build: #{build.name}, since it is not queued")
      return
    end

    prj = build.branch.project

    api_client = prj.build_server.api_client

    jobs = api_client.job.list(prj.config[:JENKINS_PROJECT])

    logger.info("Found Jobs on Build Server: #{jobs}")

    job_name = jobs.select {|j|
      j.include?('build') || j.include?('deploy')
    }.first

    logger.info("Using Job: #{job_name}")

    api_client.job.build(
        job_name,
        {
            name: build.name,
            branch: build.branch.name,
            app: (build.app.name if build.app)
        }
    )

    logger.info('wait a few sec to check status')
    sleep 5

    begin
      sleep 5
      status = api_client.job.status(job_name)
      logger.info("Job #{job_name} status: #{status}")

      case status
        when 'success', 'failure'
          build.result = status.to_sym
          build.state = :completed
        when 'running', 'aborted'
          build.state = status.to_sym
        else
          logger.error('Unknown status')
          build.state = :pending
      end
      build.save!
    end while build.state.running?

    logger.info("Finished Run build: #{build.name} -> #{build.status}")
  end
end
