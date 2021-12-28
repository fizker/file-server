import EnvironmentVariables
import Vapor

enum EnvVar: String, CaseIterable {
	case maxUploadSize = "max-upload-size"
	case uploadFolder = "upload-folder"
}

extension EnvironmentVariables where Key == EnvVar {
	var maxUploadSize: ByteCount {
		get {
			get(.maxUploadSize, map: ByteCount.init(stringLiteral:), default: "10mb")
		}
	}

	var uploadFolder: String {
		get throws {
			try get(.uploadFolder)
		}
	}
}

private struct EnvVarConfKey: StorageKey {
	typealias Value = EnvironmentVariables<EnvVar>
}

extension Application {
	var envVars: EnvironmentVariables<EnvVar> {
		get { storage[EnvVarConfKey.self]! }
		set { storage[EnvVarConfKey.self] = newValue }
	}
}
