# This module is used to patch the standard Rails routing to make it easy to
# generate localised routes in the format we want.  By adding the
# `localised: true` option to a  rails route or resource, a :locale compontent
# is added to the routing before the :format component, for example:
#
#   resource :documents, only: [:index], localised: true
#
# This generates the following routes:
#
#     /documents => {locale: 'en'}
#     /documents.fr => {locale: 'fr'}
#     /documents.json => {locale: 'en', format: 'json'}
#     /documents.fr.json => {locale: 'fr', format: 'json'}
#
module LocalisedMappingPatch
  VALID_LOCALES_REGEX = Regexp.compile(Locale.non_english.map(&:code).join("|"))

  def initialize(set, ast, defaults, controller, default_action, modyoule, to, formatted, scope_constraints, blocks, via, options_constraints, anchor, options)
    @localised_routing = options.delete(:localised)
    if localised_routing?
      options[:constraints] ||= {}
      options[:constraints][:locale] ||= VALID_LOCALES_REGEX
    end
    super set, ast, defaults, controller, default_action, modyoule, to, formatted, scope_constraints, blocks, via, options_constraints, anchor, options
  end

  # Add the optional (.:locale) component to the path for localised routes.
  def self.normalize_path(path, format)
    # The below code is done before calling `super` as the overridden method may
    # add the :format component to the end of the path and we want the
    # "(.:locale)" component to come before that.
    if localised_routing?
      path = "#{path}(.:locale)"
    end

    super path, format
  end

  # Add the default locale to the routing defaults for any localised routes.
  # This will default :locale to 'en' if it isn't explicitly present.
  def self.normalize_defaults(options)
    super(options)

    if localised_routing?
      @defaults[:locale] = I18n.default_locale.to_s
    end
  end
  private_class_method :normalize_defaults

private

  def localised_routing?
    @localised_routing
  end
end

ActionDispatch::Routing::Mapper::Mapping.send(:prepend, LocalisedMappingPatch)
