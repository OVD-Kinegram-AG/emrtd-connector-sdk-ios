Pod::Spec.new do |spec|
  spec.name          = "KinegramEmrtdConnector"
  spec.version       = "#{ENV['GITHUB_REF_NAME']}"
  spec.summary       = "Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD via a WebSocket connection."
  spec.description   = <<-DESC
    Enable the Document Validation Server (DocVal Server) to read and verify an eMRTD via a WebSocket connection.
    The DocVal server is able to read the data (like MRZ info or photo of face) and verify the
    authenticity and integrity of the data.
    If the eMRTD supports the required protocols, the DocVal Server will additionally be able to verify
    that the chip was not cloned.
    The DocVal Server will post the result to your **Result-Server**.
    DESC
  spec.homepage      = "https://ovd-kinegram-ag.github.io/emrtd-connector-sdk-ios"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "Alexander Manzer" => "alexander.manzer@kurzdigital.com" }
  spec.platform      = :ios, "13.0"
  spec.source        = { :git => "https://github.com/OVD-Kinegram-AG/emrtd-connector-sdk-ios.git", :tag => "#{spec.version}" }
  spec.swift_version = "5.1"
  spec.source_files  = "Sources/KinegramEmrtdConnector/**/*"
  spec.ios.framework = "CoreNFC", "Foundation"
  spec.xcconfig      = { 'OTHER_LDFLAGS' => '-weak_framework CoreNFC' }
  spec.test_spec "Tests" do |test_spec|
    test_spec.source_files = "Sources/KinegramEmrtdConnectorTests/**/*"
    test_spec.resources = 'Sources/KinegramEmrtdConnectorTests/**/*'
  end
end
