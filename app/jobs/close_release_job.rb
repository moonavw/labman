class CloseReleaseJob < ApplicationJob
  queue_as :default

  def perform(release_id)
    release = Release.find(release_id)

    prj = release.project

    logger.info("Closing #{release.named} at #{release.tag_name} for #{prj.named}")

    code_manager = prj.code_manager

    ## close milestone of this release
    code_manager.api_client.edit_milestone(prj.config[:GITLAB_PROJECT], release.uid, {state_event: 'close'})

    tags = code_manager.api_client.tags(prj.config[:GITLAB_PROJECT]).map(&:to_hash)

    ## get final tag of this release
    release_tag = tags.select {|tag|
      tag['name'] == release.tag_name
    }.first

    unless release_tag.present?
      logger.error("Failed to Close #{release.named} due to Invalid release tag")
      return
    end

    ## cleanup old tags of this release
    tags.select {|tag|
      tag['name'].start_with?("v#{release.name}.") && tag['name'] != release.tag_name
    }.each {|tag|
      logger.info("Remove outdated tag #{tag['name']}")
      code_manager.api_client.delete_tag(prj.config[:GITLAB_PROJECT], tag['name'])
    }

    ## go live
    # get version of live tag
    live_tag = tags.select {|tag|
      tag['name'] == Release::LIVE_TAG
    }.first

    # compare live version with this release
    if live_tag.present?
      live_version_tag = tags.select {|tag|
        tag['commit']['id'] == live_tag['commit']['id']
      }.first

      need_go_live = live_version_tag.nil? || Gem::Version.new(live_version_tag['name'].sub('v', '')) < Gem::Version.new(release.tag_name.sub('v', ''))
    else
      need_go_live = true
    end

    # point live tag to this release
    if need_go_live
      begin
        code_manager.api_client.delete_tag(prj.config[:GITLAB_PROJECT], Release::LIVE_TAG) if live_tag.present?

        code_manager.api_client.create_tag(prj.config[:GITLAB_PROJECT], Release::LIVE_TAG, release.tag_name)

        logger.info("#{release.named} GO LIVE on #{release.tag_name}")
      rescue Gitlab::Error::BadRequest => e
        logger.error("Failed #{release.named} GO LIVE")
        logger.error(e)
      end
    else
      logger.warn("Skip #{release.named} GO LIVE, since current LIVE #{live_version_tag['name']} is not lower than #{release.tag_name}")
    end


    ## cleanup the branch of this release
    begin
      release_branch = code_manager.api_client.branch(prj.config[:GITLAB_PROJECT], release.branch_name).to_hash

      if release_branch['commit']['id'] == release_tag['commit']['id']
        ## FIXME: wait for gitlab 10.5, https://gitlab.com/gitlab-org/gitlab-ce/merge_requests/16591
        # if release_branch['protected']
        #   logger.info("Unprotect branch #{release.branch_name}")
        #   code_manager.api_client.unprotect_branch(prj.config[:GITLAB_PROJECT], release.branch_name)
        # end
        logger.info("Delete branch #{release.branch_name}")
        code_manager.api_client.delete_branch(prj.config[:GITLAB_PROJECT], release.branch_name)
      end
    rescue Gitlab::Error::NotFound
      # just ignore it
    end

    release.branch.destroy if release.branch.present?
  end
end
