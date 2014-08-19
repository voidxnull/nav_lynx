require 'rack/utils'
require 'active_support/core_ext/hash'

module NavLinkHelper

  def nav_link_to(*args, &block)
    title = block_given? ? capture(&block) : args.shift
    url_options  = args[0]
    options      = args[1] || {}
    html_options = args[2] || {}

    LinkGenerator.new(request, title, url_options, controller, options, html_options).to_html
  end

  class LinkGenerator
    include ActionView::Helpers::UrlHelper
    include Rails.application.routes.url_helpers

    attr_reader :controller

    def initialize(request, title, url_options, controller, options = {}, html_options = {})
      @request      = request
      @title        = title
      @url_options  = url_options
      @html_options = html_options
      @options      = options
      @controller   = controller
    end

    def to_html
      html = link
      if wrapper
        html = content_tag(wrapper, html, :class => wrapper_classes)
      end

      html.html_safe
    end

    private

    def link
      link_to(@title, @url_options, html_options)
    end

    def html_options
      selected? ? @html_options.merge(:class => link_classes) : @html_options
    end

    def selected?
      paths_match? || segments_match?
    end

    def paths_match?
      current_path == link_path
    end

    def current_path
      comparable_path_for(@request.fullpath)
    end

    def link_path
      path = url_for(@url_options)
      comparable_path_for(path)
    end

    def comparable_path_for(path)
      ignore_params = @options[:ignore_params]
      if ignore_params == :all
        path.gsub(/\?.*/, '')
      elsif ignore_params.is_a? Array
        uri = URI(path)
        params = Rack::Utils.parse_query(uri.query).except(*ignore_params.map{ |p| p.to_s })
        uri.query = params.to_query
        uri.to_s
      else
        path
      end
    end

    def segments_match?
      path_segment && path_segment == current_segment
    end

    def path_segment
      segment_for(path_controller, current_path)
    end

    def segment_for(controller, path)
      if @options[:controller_segment]
        controller.split('/')[segment_position]
      elsif @options[:url_segment]
        path.split('/')[segment_position]
      end
    end

    def path_controller
      if @url_options.is_a?(Hash) && @url_options[:controller]
        @url_options[:controller]
      else
        controller_for(url_for(@url_options))
      end
    end

    def segment_position
      if @options[:controller_segment]
        @options[:controller_segment] - 1
      elsif @options[:url_segment]
        @options[:url_segment]
      end
    end

    def controller_for(path)
      Rails.application.routes.recognize_path(path)[:controller]
    rescue ActionController::RoutingError
      nil
    end

    def current_segment
      segment_for(current_controller, link_path)
    end

    def current_controller
      controller_for(@request.path)
    end

    def link_classes
      if @html_options[:class]
        @html_options[:class] + " #{selected_class}"
      elsif !@options[:wrapper]
        selected_class
      end
    end

    def selected_class
      @options[:selected_class] || NavLYNX.selected_class
    end

    def wrapper
      if @options[:wrapper] == false
        nil
      else
        @options[:wrapper] || NavLYNX.wrapper
      end
    end

    def wrapper_class
      if @options[:wrapper_class] == false
        nil
      else
        @options[:wrapper_class] || NavLYNX.wrapper_class
      end
    end

    def wrapper_classes
      if selected?
        "#{selected_class} #{wrapper_class}"
      else
        wrapper_class
      end
    end
  end

end
