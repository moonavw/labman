module FontAwesomeHelper
  def icon_w(icon_name, text = nil, html_options = {})
    text, html_options = nil, text if text.is_a?(Hash)

    klass = ['fa-fw']
    klass << html_options[:class] if html_options[:class].present?
    html_options.merge!(class: klass.join(' '), text: text)
    fa_icon(icon_name.to_s.dasherize, html_options)
  end
end
