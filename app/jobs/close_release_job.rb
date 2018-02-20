class CloseReleaseJob < ApplicationJob
  queue_as :default

  def perform(release_id)
    release = Release.find(release_id)

    prj = release.project

    logger.info("Closing #{release.named} at #{release.tag_name} for #{prj.named}")

    code_manager = prj.code_manager

    ## close milestone of this release
    code_manager.api_client.edit_milestone(prj.config[:GITLAB_PROJECT], release.uid, { state_event: 'close' })

    begin
      ## get final tag of this release
      release_tag = code_manager.api_client.tag(prj.config[:GITLAB_PROJECT], release.tag_name).to_hash

      ## cleanup old tags of this release
      code_manager.api_client.tags(prj.config[:GITLAB_PROJECT]).map(&:to_hash).select {|tag|
        tag['name'].start_with?("v#{release.name}.") && tag['name'] != release.tag_name
      }.each {|tag|
        logger.info("Remove outdated tag #{tag['name']}")
        code_manager.api_client.delete_tag(prj.config[:GITLAB_PROJECT], tag['name'])
      }
    rescue Gitlab::Error::NotFound
      logger.error("Failed to Close #{release.named} due to Invalid release tag")
    end


    begin
      ## get branch of this release
      release_branch = code_manager.api_client.branch(prj.config[:GITLAB_PROJECT], release.branch_name).to_hash

      ## cleanup the branch of this release
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
