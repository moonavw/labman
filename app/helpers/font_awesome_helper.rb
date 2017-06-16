module FontAwesomeHelper
  def icon_w(fa_icon, text = nil, html_options = {})
    text, html_options = nil, text if text.is_a?(Hash)

    klass = ['fa-fw']
    klass << html_options[:class] if html_options[:class].present?
    html_options.merge!(class: klass.join(' '))
    icon(fa_icon.to_s.dasherize, text, html_options)
  end
end
