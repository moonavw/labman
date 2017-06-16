$(document).on 'turbolinks:load', ->
  $('a[rel~=popover], .has-popover').popover()
  $('a[rel~=tooltip], .has-tooltip, [data-toggle=tooltip]').tooltip()