require 'equivalent-xml'

module SyncChecker
  module Checks
    DetailsCheck = Struct.new(:expected_details) do
      attr_reader :content_item
      def call(response)
        failures = []
        if response.response_code == 200
          @content_item = JSON.parse(response.body)
          if run_check?
            failures << "details body doesn't match" unless body_is_equivalent?
          end
        end
        failures
      end

    private

      def run_check?
        %w(redirect gone).exclude?(content_item["schema_name"])
      end

      def body_is_equivalent?
        content_body = content_item["details"]["body"]
        content_body.gsub!(/<td>\s*<\/td>/, "<td>&nbsp;</td>") if content_body
        expected_body = expected_details[:body]

        EquivalentXml.equivalent?(
          content_body,
          expected_body
        )
      end
    end
  end
end
