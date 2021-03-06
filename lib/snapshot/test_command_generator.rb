module Snapshot
  # Responsible for building the fully working xcodebuild command
  class TestCommandGenerator
    class << self
      def generate(device_type: nil)
        parts = prefix
        parts << "xcodebuild"
        parts += options
        parts += destination(device_type)
        parts += actions
        parts += suffix
        parts += pipe

        parts
      end

      def prefix
        ["set -o pipefail &&"]
      end

      # Path to the project or workspace as parameter
      # This will also include the scheme (if given)
      # @return [Array] The array with all the components to join
      def project_path_array
        proj = Snapshot.project.xcodebuild_parameters
        return proj if proj.count > 0
        raise "No project/workspace found"
      end

      def options
        config = Snapshot.config

        options = []
        options += project_path_array
        options << "-configuration '#{config[:configuration]}'" if config[:configuration]
        options << "-sdk '#{config[:sdk]}'" if config[:sdk]
        options << "-derivedDataPath '#{derived_data_path}'"
        # options << "-xcconfig '#{config[:xcconfig]}'" if config[:xcconfig]
        # options << "-archivePath '#{archive_path}'"
        # options << config[:xcargs] if config[:xcargs]

        options
      end

      def actions
        actions = []
        # actions << :clean if config[:clean]
        actions << :test

        actions
      end

      def suffix
        []
      end

      def pipe
        ["| tee '#{xcodebuild_log_path}' | xcpretty"]
      end

      def destination(device)
        # we now fetch the device's udid. Why? Because we might get this error message
        # > The requested device could not be found because multiple devices matched the request.
        #
        # This happens when you have multiple simulators for a given device type / iOS combination
        #   { platform:iOS Simulator, id:1685B071-AFB2-4DC1-BE29-8370BA4A6EBD, OS:9.0, name:iPhone 5 }
        #   { platform:iOS Simulator, id:A141F23B-96B3-491A-8949-813B376C28A7, OS:9.0, name:iPhone 5 }
        #

        device_udid = nil
        FastlaneCore::Simulator.all.each do |sim|
          device_udid = sim.udid if sim.name.strip == device.strip
        end

        value = "platform=iOS Simulator,id=#{device_udid},OS=#{Snapshot.config[:ios_version]}"

        return ["-destination '#{value}'"]
      end

      def xcodebuild_log_path
        file_name = "#{Snapshot.project.app_name}-#{Snapshot.config[:scheme]}.log"
        containing = File.expand_path(Snapshot.config[:buildlog_path])
        FileUtils.mkdir_p(containing)

        return File.join(containing, file_name)
      end

      def derived_data_path
        "/tmp/snapshot_derived/"
      end
    end
  end
end
