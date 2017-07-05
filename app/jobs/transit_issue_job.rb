class TransitIssueJob < ApplicationJob
  queue_as :default

  def perform(target_transitions, *issue_ids)
    Issue.where(:id.in => issue_ids).each {|issue|
      transit_issue(issue, target_transitions)
    }
  end

  private
  def transit_issue(issue, target_transitions)
    prj = issue.project
    issue_tracker = prj.issue_tracker

    logger.info("Transiting #{issue.named} to #{target_transitions}")

    r_issue = issue_tracker.api_client.Issue.find(issue.name, {fields: []})
    transitions = issue_tracker.api_client.Transition.all(issue: r_issue)

    logger.info("Available transitions: #{transitions.map(&:name)}")

    matched_transition = transitions.select {|t|
      target_transitions.any? {|text|
        t.name.include?(text)
      }
    }.first

    if matched_transition
      logger.info("Transiting #{issue.named} to matched transition: #{matched_transition.name}")

      r_issue_transition = r_issue.transitions.build
      r_issue_transition.save!(transition: {id: matched_transition.id})

      logger.info("Transited #{issue.named} to matched transition: #{matched_transition.name}")
    else
      logger.warn("Not found the matched transition for #{issue.named}, nothing happened")
    end

  end
end
