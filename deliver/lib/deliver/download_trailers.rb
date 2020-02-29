require_relative 'module'
require 'open-uri'

module Deliver
  class DownloadTrailers
    def self.run(options, path)
      UI.message("Downloading all existing trailers...")
      download(options, path)
      UI.success("Successfully downloaded all existing trailers")
    rescue => ex
      UI.error(ex)
      UI.error("Couldn't download already existing trailers from App Store Connect.")
    end

    def self.download(options, folder_path)
      v = options[:use_live_version] ? options[:app].live_version(platform: options[:platform]) : options[:app].latest_version(platform: options[:platform])

		v.trailers.each do |language, trailers|
			trailers.each do |trailer|
				containing_folder = File.join(folder_path, trailer.language)
				url = trailer.video_url
				file_type = url.split(".").last
				file_name = [trailer.device_type, file_type].join(".")

				UI.message("Downloading existing trailer '#{file_name}' for language '#{language}'")

          # If the screen shot is for an appleTV we need to store it in a way that we'll know it's an appleTV
          # screen shot later as the screen size is the same as an iPhone 6 Plus in landscape.
          if trailer.device_type == "appleTV"
            containing_folder = File.join(folder_path, "appleTV", trailer.language)
          else
            containing_folder = File.join(folder_path, trailer.language)
          end

          begin
            FileUtils.mkdir_p(containing_folder)
          rescue
            # if it's already there
          end
          path = File.join(containing_folder, file_name)
          File.binwrite(path, open(url).read)
        end
      end
    end
  end
end
