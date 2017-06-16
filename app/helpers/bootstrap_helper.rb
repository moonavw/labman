module BootstrapHelper
  def bs_context(state)
    case state.to_sym
      when :pending, :to_do, :idle
        :default
      when :running, :in_progress, :locked
        :warning
      when :success, :done
        :success
      when :failure, :aborted
        :danger
      else
        :info
    end
  end

  def panel(ctx = :default, *args, &block)
    contextual(:panel, ctx, *args, &block)
  end

  private
  def contextual(what, ctx, options = {}, &block)
    klass = [what]
    klass << "#{what}-#{ctx}" if ctx.present?
    klass << options[:class] if options[:class].present?
    options.merge!(class: klass.join(' '))
    content_tag(:div, options, &block)
  end
end
