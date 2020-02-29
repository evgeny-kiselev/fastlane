require 'spaceship/tunes/tunes'

require_relative 'module'
require_relative 'loader'
require_relative 'app_trailer'

module Deliver
  # upload trailers to App Store Connect
  class UploadTrailers
    def upload(options, trailers)
      return if options[:skip_trailers]
      return if options[:edit_live]

      app = options[:app]

      v = app.edit_version(platform: options[:platform])
      UI.user_error!("Could not find a version to edit for app '#{app.name}'") unless v

      UI.message("Starting with the upload of trailers...")
      trailers_per_language = trailers.group_by(&:language)  # GROUP BY Language

      if options[:overwrite_trailers]
        UI.message("Removing all previously uploaded trailers...")
        # First, clear all previously uploaded trailers
        trailers_per_language.keys.each do |language|
          # We have to nil check for languages not activated
          next if v.trailers[language].nil?
          v.trailers[language].each_with_index do |t, index|
			t.acceptable_devices.each do |screen_size, resolution|
				v.upload_trailer!(t.path, 1, language, t.device_type(screen_size), timestamp = "05:00", preview_image_path = nil)
			end
          end
        end
      end

      # Now, fill in the new ones
      indized = {} # per language and device type

      enabled_languages = trailers_per_language.keys
      if enabled_languages.count > 0
        v.create_languages(enabled_languages)
        lng_text = "language"
        lng_text += "s" if enabled_languages.count != 1
        Helper.show_loading_indicator("Activating #{lng_text} #{enabled_languages.join(', ')}...")
        v.save!
        # This refreshes the app version from iTC after enabling a localization
        v = app.edit_version(platform: options[:platform])
        Helper.hide_loading_indicator
      end

      trailers_per_language.each do |language, trailers_for_language|
        UI.message("Uploading #{trailers_for_language.length} trailer for language #{language}")
        trailers_for_language.each do |trailer|
		
			trailer.acceptable_devices.each do |screen_size, resolution|
			
				indized[trailer.language] ||= {}
				indized[trailer.language][trailer.device_type(screen_size)] ||= 0
				indized[trailer.language][trailer.device_type(screen_size)] += 1 # we actually start with 1... wtf iTC

				index = indized[trailer.language][trailer.device_type(screen_size)]

				if index > 3
					UI.error("Too many trailers found for device '#{trailer.device_type(screen_size)}' in '#{trailer.language}', skipping this one (#{trailer.path})")
					next
				end

				UI.message("Uploading '#{trailer.path}'... for #{trailer.formatted_name(screen_size)}")
				v.upload_trailer!(trailer.path, 1, trailer.language, trailer.device_type(screen_size), timestamp = "00:15", preview_image_path = nil)
			end
			v.save!
			v = app.edit_version
		end
        # ideally we should only save once, but itunes server can't cope it seems
        # so we save per language. See issue #349
        Helper.show_loading_indicator("Saving changes")
        v.save!
        # Refresh app version to start clean again. See issue #9859
        v = app.edit_version
        Helper.hide_loading_indicator
      end
      UI.success("Successfully uploaded trailers to App Store Connect")
    end

    def collect_trailers(options)
      return [] if options[:skip_trailers]
      return collect_trailers_for_languages(options[:trailers_path], options[:ignore_language_directory_validation])
    end

    def collect_trailers_for_languages(path, ignore_validation)
		trailers = []
		extensions = '{mp4}'

		available_languages = UploadScreenshots.available_languages.each_with_object({}) do |lang, lang_hash|
			lang_hash[lang.downcase] = lang
		end

		Loader.language_folders(path, ignore_validation).each do |lng_folder|
			language = File.basename(lng_folder)
			# Check to see if we need to traverse multiple platforms or just a single platform
			if language == Loader::APPLE_TV_DIR_NAME
			  trailers.concat(collect_trailers_for_languages(File.join(path, language), ignore_validation))
			  next
			end

			files = Dir.glob(File.join(lng_folder, "*.#{extensions}"), File::FNM_CASEFOLD).sort
			next if files.count == 0

			preview_image_found = Dir.glob(File.join(lng_folder, "*_preview.jpg"), File::FNM_CASEFOLD).count > 0

			UI.important("Preview are detected!") if preview_image_found

			language_dir_name = File.basename(lng_folder)

			if available_languages[language_dir_name.downcase].nil?
				UI.user_error!("#{language_dir_name} is not an available language. Please verify that your language codes are available in iTunesConnect. See https://developer.apple.com/library/content/documentation/LanguagesUtilities/Conceptual/iTunesConnect_Guide/Chapters/AppStoreTerritories.html for more information.")
			end

			language = available_languages[language_dir_name.downcase]

			files.each do |file_path|	
				trailers << AppTrailer.new(file_path, language)
			end
		end

      # Checking if the device type exists in spaceship
      # Ex: iPhone 6.1 inch isn't supported in App Store Connect but need
      # to have it in there for frameit support
      unaccepted_device_shown = false
      trailers.select! do |trailer|
        exists = trailer.acceptable_devices.count != 0
        unless exists
          UI.important("Unaccepted device trailer are detected! 🚫 Trailer file will be skipped. 🏃") unless unaccepted_device_shown
          unaccepted_device_shown = true

          UI.important("🏃 Skipping trailer file: #{trailer.path} - Not an accepted App Store Connect device...")
        end
        exists
      end

      return trailers
    end

    # helper method so Spaceship::Tunes.client.available_languages is easier to test
    def self.available_languages
      if Helper.test?
        FastlaneCore::Languages::ALL_LANGUAGES
      else
        Spaceship::Tunes.client.available_languages
      end
    end
  end
end
