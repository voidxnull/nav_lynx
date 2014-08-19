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
      and_condition = @options[:and_condition]
      or_condition = @options[:or_condition]
      if and_condition
        and_condition.call and (paths_match? || segments_match?)
      elsif or_condition
        or_condition.call or (paths_match? || segments_match?)
      else
        paths_match? || segments_match?
      end
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
      use_params = @options[:use_params]
      ignore_params = @options[:ignore_params]

      if use_params
        apply_use_params_to_path(use_params, path)
      elsif ignore_params
        apply_ignore_params_to_path(ignore_params, path)
      else
        path
      end
    end

    def apply_use_params_to_path(use_params, path)
      if use_params.is_a? Array
        uri = URI(path)
        params = Rack::Utils.parse_query(uri.query).slice(*use_params.map{ |p| p.to_s })
        new_query = params.to_query
        uri.query = new_query unless new_query.empty?
        uri.to_s
      elsif use_params.is_a? Hash
        uri = URI(path)
        use_params = use_params.inject({}) do |options, (key, value)|
          options[key.to_s] = value.to_s
          options
        end
        params = Rack::Utils.parse_query(uri.query)
        new_query = use_params.select { |k, v| params[k] == v }.to_query
        uri.query = new_query unless new_query.empty?
        uri.to_s
      else
        path
      end
    end

    def apply_ignore_params_to_path(ignore_params, path)
      if ignore_params == :all
        path.gsub(/\?.*/, '')
      elsif ignore_params.is_a? Array
        uri = URI(path)
        params = Rack::Utils.parse_query(uri.query).except(*ignore_params.map{ |p| p.to_s })
        new_query = params.to_query
        uri.query = new_query.empty? ? nil : new_query
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
