class SyncTestStatusJob < ApplicationJob
  queue_as :default

  def perform(*test_ids)
    Test.without_state(:completed, :aborted).where(:id.in => test_ids).each {|test|
      sync_test_status(test)
    }
  end

  private
  def sync_test_status(test)
    logger.info("Syncing #{test.named}")

    prj = test.project
    build_server = prj.build_server

    job_name = test.job_name

    return unless build_server.api_client.job.exists?(job_name)

    status = build_server.api_client.job.status(job_name)
    logger.info("Job #{job_name} status: #{status}")

    case status
      when 'success', 'failure'
        test.result = status.to_sym
        test.state = :completed
      when 'running', 'aborted'
        test.state = status.to_sym
      else
        logger.error('Unknown status')
        test.state = :aborted
    end
    test.save!

    logger.info("Synced #{test.named} -> #{test.status}")
  end
end
