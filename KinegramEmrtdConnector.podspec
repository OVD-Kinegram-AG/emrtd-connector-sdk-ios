Pod::Spec.new do |spec|
  spec.name          = "KinegramEmrtdConnector"
  spec.version       = "2.1.1"
  spec.summary       = "Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD via a WebSocket v2 connection."
  spec.description   = <<-DESC
    Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD via a WebSocket v2 connection.

    V2 solves the iOS 20-second NFC timeout issue by moving APDU exchanges to the device. Instead of relaying
    every APDU through the server (causing latency to accumulate), V2 performs bulk reading locally and uses
    the server only for security-critical operations.

    The DocVal server is able to read the data (like MRZ info or photo of face) and verify the
    authenticity and integrity of the data.
    If the eMRTD supports the required protocols, the DocVal Server will additionally be able to verify
    that the chip was not cloned.
    The DocVal Server will post the result to your **Result-Server**.
    DESC
  spec.homepage      = "https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "Alexander Manzer" => "alexander.manzer@kurzdigital.com" }
  spec.platform      = :ios, "15.0"
  spec.source        = { :git => "https://github.com/OVD-Kinegram-AG/emrtd-connector-sdk-ios.git", :tag => "#{spec.version}" }
  spec.swift_version = "5.7"

  # Source files for the Swift connector layer
  spec.source_files  = "Sources/KinegramEmrtdConnector/**/*.swift"

  # Binary framework dependency (the core eMRTD reading library)
  spec.vendored_frameworks = "Framework/KinegramEmrtd.xcframework"

  # Preserve paths to ensure XCFramework is available during build
  spec.preserve_paths = "Framework/KinegramEmrtd.xcframework"

  # Privacy manifest for Apple's privacy requirements
  spec.resource_bundles = {
    'KinegramEmrtdConnector' => ['Sources/KinegramEmrtdConnector/PrivacyInfo.xcprivacy']
  }

  # Required system frameworks
  spec.frameworks = "CoreNFC", "Foundation"

  # CoreNFC is weakly linked to support simulator builds
  # Framework search paths for vendored XCFramework
  spec.xcconfig = {
    'OTHER_LDFLAGS' => '-weak_framework CoreNFC',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/KinegramEmrtdConnector/Framework"'
  }

  # Pod target xcconfig to ensure XCFramework is in search path during compilation
  # Exclude x86_64 simulator architecture as the XCFramework only supports arm64
  spec.pod_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/KinegramEmrtdConnector/Framework" "${PODS_XCFRAMEWORKS_BUILD_DIR}/KinegramEmrtd"',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64'
  }

  # User target xcconfig to exclude x86_64 from simulator builds
  spec.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'x86_64'
  }
end
