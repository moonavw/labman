class PublishReleaseJob < ApplicationJob
  queue_as :default

  def perform(*release_ids)
    Release.with_state(:in_progress).where(published_on: Release::PUBLISH_TAG, :tag_name.ne => nil, :id.in => release_ids).each {|release|
      publish_release(release)
    }
  end

  private
  def publish_release(release)
    logger.info("Publishing #{release.named}")

    prj = release.project
    code_manager = prj.code_manager

    # delete existing publish tag if found any
    begin
      code_manager.api_client.delete_tag(prj.config[:GITLAB_PROJECT], Release::PUBLISH_TAG)
    rescue Gitlab::Error::NotFound
      # just ignore it
    end

    # create new publish tag
    begin
      code_manager.api_client.create_tag(prj.config[:GITLAB_PROJECT], Release::PUBLISH_TAG, release.tag_name)
      release.update!(published_on: release.tag_name)

      logger.info("Published #{release.named} on #{release.published_on}")
    rescue Gitlab::Error::BadRequest => e
      release.update!(published_on: nil)
      logger.error("Failed Publishing #{release.named}")
      logger.error(e)
    end
  end
end
