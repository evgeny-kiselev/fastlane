require 'fastlane_core/configuration/config_item'
require 'credentials_manager/appfile_config'

require_relative 'module'
require_relative 'upload_assets'

module Deliver
  # rubocop:disable Metrics/ClassLength
  class Options
    def self.available_options
      user = CredentialsManager::AppfileConfig.try_fetch_value(:itunes_connect_id)
      user ||= CredentialsManager::AppfileConfig.try_fetch_value(:apple_id)
      user ||= ENV["DELIVER_USER"]

      [
        FastlaneCore::ConfigItem.new(key: :username,
                                     short_option: "-u",
                                     env_name: "DELIVER_USERNAME",
                                     description: "Your Apple ID Username",
                                     default_value: user,
                                     default_value_dynamic: true),
        FastlaneCore::ConfigItem.new(key: :app_identifier,
                                     short_option: "-a",
                                     env_name: "DELIVER_APP_IDENTIFIER",
                                     description: "The bundle identifier of your app",
                                     optional: true,
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:app_identifier),
                                     default_value_dynamic: true),
        FastlaneCore::ConfigItem.new(key: :thread_count,
                                     env_name: "DELIVER_THREAD_COUNT",
                                     description: "Threads count for upload/download screenshots",
                                     default_value: 6,
                                     is_string: false),
        # version
        FastlaneCore::ConfigItem.new(key: :app_version,
                                     short_option: '-z',
                                     description: "The version that should be edited or created",
                                     optional: true),

        # binary / build
        FastlaneCore::ConfigItem.new(key: :ipa,
                                     short_option: "-i",
                                     optional: true,
                                     env_name: "DELIVER_IPA_PATH",
                                     description: "Path to your ipa file",
                                     code_gen_sensitive: true,
                                     default_value: Dir["*.ipa"].sort_by { |x| File.mtime(x) }.last,
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find ipa file at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                       UI.user_error!("'#{value}' doesn't seem to be an ipa file") unless value.end_with?(".ipa")
                                     end,
                                     conflicting_options: [:pkg],
                                     conflict_block: proc do |value|
                                       UI.user_error!("You can't use 'ipa' and '#{value.key}' options in one run.")
                                     end),
        FastlaneCore::ConfigItem.new(key: :pkg,
                                     short_option: "-c",
                                     optional: true,
                                     env_name: "DELIVER_PKG_PATH",
                                     description: "Path to your pkg file",
                                     code_gen_sensitive: true,
                                     default_value: Dir["*.pkg"].sort_by { |x| File.mtime(x) }.last,
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find pkg file at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                       UI.user_error!("'#{value}' doesn't seem to be a pkg file") unless value.end_with?(".pkg")
                                     end,
                                     conflicting_options: [:ipa],
                                     conflict_block: proc do |value|
                                       UI.user_error!("You can't use 'pkg' and '#{value.key}' options in one run.")
                                     end),
        FastlaneCore::ConfigItem.new(key: :build_number,
                                     short_option: "-n",
                                     description: "If set the given build number (already uploaded to iTC) will be used instead of the current built one",
                                     optional: true,
                                     conflicting_options: [:ipa, :pkg],
                                     conflict_block: proc do |value|
                                       UI.user_error!("You can't use 'build_number' and '#{value.key}' options in one run.")
                                     end),
        FastlaneCore::ConfigItem.new(key: :platform,
                                     short_option: "-j",
                                     env_name: "DELIVER_PLATFORM",
                                     description: "The platform to use (optional)",
                                     optional: true,
                                     default_value: "ios",
                                     verify_block: proc do |value|
                                       UI.user_error!("The platform can only be ios, appletvos, or osx") unless %('ios', 'appletvos', 'osx').include?(value)
                                     end),

        # live version
        FastlaneCore::ConfigItem.new(key: :edit_live,
                                     short_option: "-o",
                                     optional: true,
                                     default_value: false,
                                     env_name: "DELIVER_EDIT_LIVE",
                                     description: "Modify live metadata, this option disables ipa upload and screenshot upload",
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :use_live_version,
                                     description: "Force usage of live version rather than edit version",
                                     is_string: false,
                                     default_value: false),

        # paths
        FastlaneCore::ConfigItem.new(key: :metadata_path,
                                     short_option: '-m',
                                     description: "Path to the folder containing the metadata files",
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :screenshots_path,
                                     short_option: '-w',
                                     description: "Path to the folder containing the screenshots",
                                     optional: true),
		FastlaneCore::ConfigItem.new(key: :trailers_path,
                                     description: "Path to the folder containing the trailers",
                                     optional: true),							 

        # skip
        FastlaneCore::ConfigItem.new(key: :skip_binary_upload,
                                     description: "Skip uploading an ipa or pkg to App Store Connect",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :skip_screenshots,
                                     description: "Don't upload the screenshots",
                                     is_string: false,
                                     default_value: false),
		FastlaneCore::ConfigItem.new(key: :skip_trailers,
                                     description: "Don't upload the trailers",
                                     is_string: false,
                                     default_value: false),							 
        FastlaneCore::ConfigItem.new(key: :skip_metadata,
                                     description: "Don't upload the metadata (e.g. title, description). This will still upload screenshots",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :skip_app_version_update,
                                     description: "Don't update app version for submission",
                                     is_string: false,
                                     default_value: false),

        # how to operate
        FastlaneCore::ConfigItem.new(key: :force,
                                     short_option: "-f",
                                     description: "Skip the HTML report file verification",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :overwrite_screenshots,
                                     env_name: "DELIVER_OVERWRITE_SCREENSHOTS",
                                     description: "Clear all previously uploaded screenshots before uploading the new ones",
                                     is_string: false,
									 default_value: false),
		FastlaneCore::ConfigItem.new(key: :overwrite_trailers,
                                     env_name: "DELIVER_OVERWRITE_TRAILERS",
                                     description: "Clear all previously uploaded trailers before uploading the new ones",
                                     is_string: false,							 
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :submit_for_review,
                                     env_name: "DELIVER_SUBMIT_FOR_REVIEW",
                                     description: "Submit the new version for Review after uploading everything",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :reject_if_possible,
                                     env_name: "DELIVER_REJECT_IF_POSSIBLE",
                                     description: "Rejects the previously submitted build if it's in a state where it's possible",
                                     is_string: false,
                                     default_value: false),

        # release
        FastlaneCore::ConfigItem.new(key: :automatic_release,
                                     description: "Should the app be automatically released once it's approved? (Can not be used together with `auto_release_date`)",
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :auto_release_date,
                                     env_name: "DELIVER_AUTO_RELEASE_DATE",
                                     description: "Date in milliseconds for automatically releasing on pending approval (Can not be used together with `automatic_release`)",
                                     is_string: false,
                                     optional: true,
                                     conflicting_options: [:automatic_release],
                                     conflict_block: proc do |value|
                                       UI.user_error!("You can't use 'auto_release_date' and '#{value.key}' options together.")
                                     end),
        FastlaneCore::ConfigItem.new(key: :phased_release,
                                     description: "Enable the phased release feature of iTC",
                                     optional: true,
                                     is_string: false,
                                     default_value: false),
        FastlaneCore::ConfigItem.new(key: :reset_ratings,
                                    description: "Reset the summary rating when you release a new version of the application",
                                    optional: true,
                                    is_string: false,
                                    default_value: false),

        # other app configuration
        FastlaneCore::ConfigItem.new(key: :price_tier,
                                     short_option: "-r",
                                     description: "The price tier of this application",
                                     is_string: false,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :app_rating_config_path,
                                     short_option: "-g",
                                     description: "Path to the app rating's config",
                                     is_string: true,
                                     optional: true,
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find config file at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                       UI.user_error!("'#{value}' doesn't seem to be a JSON file") unless FastlaneCore::Helper.json_file?(File.expand_path(value))
                                     end),
        FastlaneCore::ConfigItem.new(key: :submission_information,
                                     short_option: "-b",
                                     description: "Extra information for the submission (e.g. compliance specifications, IDFA settings)",
                                     is_string: false,
                                     optional: true),

        # affiliation
        FastlaneCore::ConfigItem.new(key: :team_id,
                                     short_option: "-k",
                                     env_name: "DELIVER_TEAM_ID",
                                     description: "The ID of your App Store Connect team if you're in multiple teams",
                                     optional: true,
                                     is_string: false, # as we also allow integers, which we convert to strings anyway
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_id),
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       ENV["FASTLANE_ITC_TEAM_ID"] = value.to_s
                                     end),
        FastlaneCore::ConfigItem.new(key: :team_name,
                                     short_option: "-e",
                                     env_name: "DELIVER_TEAM_NAME",
                                     description: "The name of your App Store Connect team if you're in multiple teams",
                                     optional: true,
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:itc_team_name),
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       ENV["FASTLANE_ITC_TEAM_NAME"] = value.to_s
                                     end),
        FastlaneCore::ConfigItem.new(key: :dev_portal_team_id,
                                     short_option: "-s",
                                     env_name: "DELIVER_DEV_PORTAL_TEAM_ID",
                                     description: "The short ID of your Developer Portal team, if you're in multiple teams. Different from your iTC team ID!",
                                     optional: true,
                                     is_string: true,
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:team_id),
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       ENV["FASTLANE_TEAM_ID"] = value.to_s
                                     end),
        FastlaneCore::ConfigItem.new(key: :dev_portal_team_name,
                                     short_option: "-y",
                                     env_name: "DELIVER_DEV_PORTAL_TEAM_NAME",
                                     description: "The name of your Developer Portal team if you're in multiple teams",
                                     optional: true,
                                     code_gen_sensitive: true,
                                     default_value: CredentialsManager::AppfileConfig.try_fetch_value(:team_name),
                                     default_value_dynamic: true,
                                     verify_block: proc do |value|
                                       ENV["FASTLANE_TEAM_NAME"] = value.to_s
                                     end),
        # rubocop:disable Metrics/LineLength
        FastlaneCore::ConfigItem.new(key: :itc_provider,
                                     env_name: "DELIVER_ITC_PROVIDER",
                                     description: "The provider short name to be used with the iTMSTransporter to identify your team. This value will override the automatically detected provider short name. To get provider short name run `pathToXcode.app/Contents/Applications/Application\\ Loader.app/Contents/itms/bin/iTMSTransporter -m provider -u 'USERNAME' -p 'PASSWORD' -account_type itunes_connect -v off`. The short names of providers should be listed in the second column",
                                     optional: true),
        # rubocop:enable Metrics/LineLength

        # precheck
        FastlaneCore::ConfigItem.new(key: :run_precheck_before_submit,
                                     short_option: "-x",
                                     env_name: "DELIVER_RUN_PRECHECK_BEFORE_SUBMIT",
                                     description: "Run precheck before submitting to app review",
                                     is_string: false,
                                     default_value: true),
        FastlaneCore::ConfigItem.new(key: :precheck_default_rule_level,
                                     short_option: "-d",
                                     env_name: "DELIVER_PRECHECK_DEFAULT_RULE_LEVEL",
                                     description: "The default precheck rule level unless otherwise configured",
                                     is_string: false,
                                     default_value: :warn),

        # App Metadata
        FastlaneCore::ConfigItem.new(key: :individual_metadata_items,
                                     env_name: "DELIVER_INDIVUDAL_METADATA_ITEMS",
                                     description: "An array of localized metadata items to upload individually by language so that errors can be identified. E.g. ['name', 'keywords', 'description']. Note: slow",
                                     is_string: false,
                                     type: Array,
                                     default_value: []),

        # Non Localised
        FastlaneCore::ConfigItem.new(key: :app_icon,
                                     description: "Metadata: The path to the app icon",
                                     optional: true,
                                     short_option: "-l",
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find png file at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                       UI.user_error!("'#{value}' doesn't seem to be one of the supported files. supported: #{Deliver::UploadAssets::SUPPORTED_ICON_EXTENSIONS.join(',')}") unless Deliver::UploadAssets::SUPPORTED_ICON_EXTENSIONS.include?(File.extname(value).downcase)
                                     end),
        FastlaneCore::ConfigItem.new(key: :apple_watch_app_icon,
                                     description: "Metadata: The path to the Apple Watch app icon",
                                     optional: true,
                                     short_option: "-q",
                                     verify_block: proc do |value|
                                       UI.user_error!("Could not find png file at path '#{File.expand_path(value)}'") unless File.exist?(value)
                                       UI.user_error!("'#{value}' doesn't seem to be one of the supported files. supported: #{Deliver::UploadAssets::SUPPORTED_ICON_EXTENSIONS.join(',')}") unless Deliver::UploadAssets::SUPPORTED_ICON_EXTENSIONS.include?(File.extname(value).downcase)
                                     end),
        FastlaneCore::ConfigItem.new(key: :copyright,
                                     description: "Metadata: The copyright notice",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :primary_category,
                                     description: "Metadata: The english name of the primary category (e.g. `Business`, `Books`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :secondary_category,
                                     description: "Metadata: The english name of the secondary category (e.g. `Business`, `Books`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :primary_first_sub_category,
                                     description: "Metadata: The english name of the primary first sub category (e.g. `Educational`, `Puzzle`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :primary_second_sub_category,
                                     description: "Metadata: The english name of the primary second sub category (e.g. `Educational`, `Puzzle`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :secondary_first_sub_category,
                                     description: "Metadata: The english name of the secondary first sub category (e.g. `Educational`, `Puzzle`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :secondary_second_sub_category,
                                     description: "Metadata: The english name of the secondary second sub category (e.g. `Educational`, `Puzzle`)",
                                     optional: true,
                                     is_string: true),
        FastlaneCore::ConfigItem.new(key: :trade_representative_contact_information,
                                     description: "Metadata: A hash containing the trade representative contact information",
                                     optional: true,
                                     is_string: false,
                                     type: Hash),
        FastlaneCore::ConfigItem.new(key: :app_review_information,
                                     description: "Metadata: A hash containing the review information",
                                     optional: true,
                                     is_string: false,
                                     type: Hash),
        FastlaneCore::ConfigItem.new(key: :app_review_attachment_file,
                                     description: "Metadata: Path to the app review attachment file",
                                     optional: true,
                                     is_string: true),
        # Localised
        FastlaneCore::ConfigItem.new(key: :description,
                                     description: "Metadata: The localised app description",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :name,
                                     description: "Metadata: The localised app name",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :subtitle,
                                     description: "Metadata: The localised app subtitle",
                                     optional: true,
                                     is_string: false,
                                     type: Hash,
                                     verify_block: proc do |value|
                                       UI.user_error!(":subtitle must be a hash, with the language being the key") unless value.kind_of?(Hash)
                                     end),
        FastlaneCore::ConfigItem.new(key: :keywords,
                                     description: "Metadata: An array of localised keywords",
                                     optional: true,
                                     is_string: false,
                                     type: Hash,
                                     verify_block: proc do |value|
                                       UI.user_error!(":keywords must be a hash, with the language being the key") unless value.kind_of?(Hash)
                                       value.each do |language, keywords|
                                         # Auto-convert array to string
                                         keywords = keywords.join(", ") if keywords.kind_of?(Array)
                                         value[language] = keywords

                                         UI.user_error!("keywords must be a hash with all values being strings") unless keywords.kind_of?(String)
                                       end
                                     end),
        FastlaneCore::ConfigItem.new(key: :promotional_text,
                                     description: "Metadata: An array of localised promotional texts",
                                     optional: true,
                                     is_string: false,
                                     type: Hash,
                                     verify_block: proc do |value|
                                       UI.user_error!(":keywords must be a hash, with the language being the key") unless value.kind_of?(Hash)
                                     end),
        FastlaneCore::ConfigItem.new(key: :release_notes,
                                     description: "Metadata: Localised release notes for this version",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :privacy_url,
                                     description: "Metadata: Localised privacy url",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :apple_tv_privacy_policy,
                                     description: "Metadata: Localised Apple TV privacy policy text",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :support_url,
                                     description: "Metadata: Localised support url",
                                     optional: true,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :marketing_url,
                                     description: "Metadata: Localised marketing url",
                                     optional: true,
                                     is_string: false),
        # The verify_block has been removed from here and verification now happens in Deliver::DetectValues
        # Verification needed Spaceship::Tunes.client which required the Deliver::Runner to already by started
        FastlaneCore::ConfigItem.new(key: :languages,
                                     description: "Metadata: List of languages to activate",
                                     type: Array,
                                     optional: true),
        FastlaneCore::ConfigItem.new(key: :ignore_language_directory_validation,
                                     env_name: "DELIVER_IGNORE_LANGUAGE_DIRECTORY_VALIDATION",
                                     description: "Ignore errors when invalid languages are found in metadata and screenshot directories",
                                     default_value: false,
                                     is_string: false),
        FastlaneCore::ConfigItem.new(key: :precheck_include_in_app_purchases,
                                     env_name: "PRECHECK_INCLUDE_IN_APP_PURCHASES",
                                     description: "Should precheck check in-app purchases?",
                                     is_string: false,
                                     optional: true,
                                     default_value: true),

        # internal
        FastlaneCore::ConfigItem.new(key: :app,
                                     short_option: "-p",
                                     env_name: "DELIVER_APP_ID",
                                     description: "The (spaceship) app ID of the app you want to use/modify",
                                     is_string: false) # don't add any verification here, as it's used to store a spaceship ref
      ]
    end
  end
  # rubocop:enable Metrics/ClassLength
end
