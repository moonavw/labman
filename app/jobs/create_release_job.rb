class CreateReleaseJob < ApplicationJob
  queue_as :default

  def perform(release_id)
    release = Release.find(release_id)

    prj = release.project

    logger.info("Creating #{release.named} milestone for #{prj.named}")

    if release.uid.present?
      logger.warn("Already existing #{release.named} milestone at #{release.uid}")
      return
    end

    code_manager = prj.code_manager
    milestone = code_manager.api_client.create_milestone(prj.config[:GITLAB_PROJECT], release.name, { due_date: release.due_date }).to_hash
    release.uid = milestone['id']
    release.save!

    logger.info("Created #{release.named} milestone at #{release.uid}")
  end
end
