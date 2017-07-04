module ContextualHelper
  def bs_context(state)
    case state.to_sym
      when :pending, :to_do, :opened
        :default
      when :running, :in_progress, :locked, :approved
        :warning
      when :success, :done, :accepted
        :success
      when :failure, :aborted
        :danger
      else
        :info
    end
  end
end
