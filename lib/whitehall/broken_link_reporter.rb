require 'gds_api/link_checker_api'

# Generates CSV reports of all public documents containing broken links.
module Whitehall
  class BrokenLinkReporter
    attr_reader :csv_reports, :logger

    def initialize(csv_reports_dir, logger = Rails.logger)
      @csv_reports_dir = csv_reports_dir
      @csv_reports = {}
      @logger = logger
    end

    def generate_reports
      incomplete_checkers = public_editions.find_each.map do |edition|
        logger.info "Checking #{edition.type} (#{edition.id}) for bad links"

        checker = EditionChecker.new(edition)
        checker.start_check
        checker
      end

      # @TODO this could continue forever, and it does no rate limiting
      # so need to either be confident it's going to work or have means to
      # stop it playing nasty
      loop do
        incomplete_checkers = incomplete_checkers.reject do |checker|
          checker.check_progress
          if checker.is_complete? && checker.broken_links.any?
            csv_for_organisation_slug(checker.organisation_slug) << csv_row_for(checker)
          end
          checker.is_complete?
        end

        break if incomplete_checkers.count == 0
      end

      close_reports
    end

  private

    def public_editions
      Edition.publicly_visible.with_translations
    end

    def csv_row_for(checker)
      [
        checker.public_url,
        checker.admin_url,
        checker.timestamp,
        checker.edition_type,
        checker.broken_link_uris.size,
        checker.broken_link_uris.join("\r\n"),
      ]
    end

    def csv_for_organisation_slug(slug)
      csv_reports[slug] ||= CsvReport.new(csv_report_path(slug))
    end

    def csv_report_path(file_prefix)
      Pathname.new(@csv_reports_dir).join("#{file_prefix}_broken_links.csv")
    end

    def close_reports
      csv_reports.each_value(&:close)
    end

    class EditionChecker
      attr_reader :last_report, :organisation_slug, :edition_type, :public_url,
        :admin_url, :timestamp, :links

      def initialize(edition)
        @organisation_slug = organisation(edition).try(:slug) || 'no-organisation'
        @edition_type = edition.type
        @public_url = Whitehall.url_maker.public_document_url(
          edition, host: public_host, protocol: 'https'
        )
        @admin_url = Whitehall.url_maker.admin_edition_url(
          edition, host: admin_host, protocol: 'https'
        )

        @timestamp = edition.public_timestamp.to_s
        @links = Govspeak::LinkExtractor.new(edition.body).links
      end

      def is_complete?
        return true unless has_links?
        return false unless last_report
        last_report.status == :completed
      end

      def start_check
        return unless has_links?
        @last_report = Whitehall.link_checker_api_client.create_batch(links)
      end

      def check_progress
        return unless has_links?
        @last_report = Whitehall.link_checker_api_client.get_batch(batch_id)
      end

      def batch_id
        last_report.id
      end

      def has_links?
        links.any?
      end

      def broken_links
        report_links = last_report ? last_report.links : []
        report_links.select { |l| l.status == :broken }
      end

      def broken_link_uris
        broken_links.map(&:uri)
      end

    private

      # These hosts are hardcoded because we run this on preview but want the
      # generated URLs to be production ones.
      def public_host
        "www.gov.uk"
      end

      def admin_host
        'whitehall-admin.publishing.service.gov.uk'
      end

      def organisation(edition)
        if edition.respond_to?(:worldwide_organisations)
          edition.worldwide_organisations.first || edition.organisations.first
        elsif edition.respond_to?(:lead_organisations)
          edition.lead_organisations.first || edition.organisations.first
        else
          edition.organisations.first
        end
      end
    end

    class CsvReport
      delegate :<<, :close, to: :csv

      def initialize(file_path)
        @csv = CSV.open(file_path, 'w', encoding: 'UTF-8')
        @csv << headings
      end

    private
      def csv
        @csv
      end

      def headings
        ["page", "admin link", "public timestamp", "format", "broken link count", "broken links"]
      end
    end
  end
end
