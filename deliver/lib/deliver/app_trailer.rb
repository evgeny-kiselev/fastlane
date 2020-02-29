require 'streamio-ffmpeg'

require_relative 'module'

module Deliver
  # AppTrailer represents one trailer for one specific locale and
  # device type.
  class AppTrailer

    attr_accessor :path

    attr_accessor :language
	
	attr_accessor :acceptable_devices

    # @param path (String) path to the trailer file
    # @param language (String) Language of this trailer (e.g. English)
    # @param screen_size (Deliver::AppTrailer::ScreenSize) the screen size, which
    #  will automatically be calculated when you don't set it.
    def initialize(path, language)
      self.path = path
      self.language = language
	  self.acceptable_devices = []
      self.acceptable_devices = self.class.calculate_screen_size(path)

      UI.error("Looks like the trailer given (#{path}) does not match the requirements") unless self.is_valid?
    end

    # The iTC API requires a different notation for the device
    def device_type(screen_size)
      matching = {
        ScreenSize::IOS_35 => "iphone35",
        ScreenSize::IOS_40 => "iphone4",
        ScreenSize::IOS_47 => "iphone6", # also 7 and 8
        ScreenSize::IOS_55 => "iphone6Plus", # also 7 Plus & 8 Plus
        ScreenSize::IOS_58 => "iphone58",
        ScreenSize::IOS_65 => "iphone65",
        ScreenSize::IOS_IPAD => "ipad",
        ScreenSize::IOS_IPAD_10_5 => "ipad105",
        ScreenSize::IOS_IPAD_11 => "ipadPro11",
        ScreenSize::IOS_IPAD_PRO => "ipadPro",
        ScreenSize::IOS_IPAD_PRO_12_9 => "ipadPro129",
        ScreenSize::MAC => "desktop",
        ScreenSize::IOS_APPLE_WATCH => "watch",
        ScreenSize::IOS_APPLE_WATCH_SERIES4 => "watchSeries4",
        ScreenSize::APPLE_TV => "appleTV"
      }
      return matching[screen_size]
    end

    # Nice name
    def formatted_name(screen_size)
      matching = {
        ScreenSize::IOS_35 => "iPhone 4",
        ScreenSize::IOS_40 => "iPhone 5",
        ScreenSize::IOS_47 => "iPhone 6", # and 7
        ScreenSize::IOS_55 => "iPhone 6 Plus", # and 7 Plus
        ScreenSize::IOS_58 => "iPhone XS",
        ScreenSize::IOS_61 => "iPhone XR",
        ScreenSize::IOS_65 => "iPhone XS Max",
        ScreenSize::IOS_IPAD => "iPad",
        ScreenSize::IOS_IPAD_10_5 => "iPad 10.5",
        ScreenSize::IOS_IPAD_11 => "iPad 11",
        ScreenSize::IOS_IPAD_PRO => "iPad Pro",
        ScreenSize::IOS_IPAD_PRO_12_9 => "iPad Pro (12.9-inch) (3rd generation)",
        ScreenSize::MAC => "Mac",
        ScreenSize::APPLE_TV => "Apple TV"
      }
      return matching[screen_size]
    end

    # Validates the given screenshots (size and format)
    def is_valid?
      return false unless ['mp4', 'mov', 'm4v'].include?(self.path.split(".").last)
	  return false unless File.size(path) <= 500 * 1024 * 1024
	  movie = FFMPEG::Movie.new(path)
	  return false unless ['h264'].include?(movie.video_codec)
	  return false unless movie.frame_rate.to_f == 30.0
	  duration = movie.duration.to_f
	  return duration >= 15 && duration <= 30
    end

    # reference: https://help.apple.com/app-store-connect/#/devd274dd925
    def self.devices
      # This list does not include iPad Pro 12.9-inch (3rd generation)
      # because it has same resoluation as IOS_IPAD_PRO and will clobber
      return {
        ScreenSize::IOS_65 => [
          [886, 1920],
          [1920, 886]
        ],
    #    ScreenSize::IOS_61 => [
    #      [886, 1920],
    #      [1920, 886]
    #    ],
    #    ScreenSize::IOS_58 => [
    #      [886, 1920],
    #      [1920, 886]
    #    ],
        ScreenSize::IOS_55 => [
          [1080, 1920],
          [1920, 1080]
        ],
    #    ScreenSize::IOS_47 => [
    #      [750, 1334],
    #      [1334, 750]
    #    ],
    #    ScreenSize::IOS_40 => [
    #      [1080, 1920],
    #      [1920, 1080]
    #    ],
    #    ScreenSize::IOS_IPAD => [ # 9.7 inch
    #      [900, 1200],
    #      [1200, 900]
    #    ],
    #    ScreenSize::IOS_IPAD_10_5 => [
    #      [1200, 1600],
    #      [1600, 1200]
    #    ],
    #    ScreenSize::IOS_IPAD_11 => [
    #      [1200, 1600],
    #      [1600, 1200]
    #    ],
        ScreenSize::IOS_IPAD_PRO => [
          [1200, 1600],
          [1600, 1200],
		  [900, 1200],
		  [1200, 900]
        ],
		ScreenSize::IOS_IPAD_PRO_12_9 => [
          [1200, 1600],
          [1600, 1200]
        ],
        ScreenSize::MAC => [
          [1920, 1080]
        ],
        ScreenSize::APPLE_TV => [
          [1920, 1080]
        ]
      }
    end

    def self.calculate_screen_size(path)
		movie = FFMPEG::Movie.new(path)
		size = [movie.width, movie.height]
		ac_devices = []

		UI.user_error!("Could not find or parse file at path '#{path}'") if size.nil? || size.count == 0

		devices.each do |screen_size, resolutions|
			if resolutions.include?(size)
				ac_devices << [screen_size, resolutions]
			end
		end
		if(ac_devices.count > 0)
			filename = Pathname.new(path).basename.to_s
			return ac_devices
		end
		UI.user_error!("Unsupported screen size #{size} for path '#{path}'")
		end
	end
end
