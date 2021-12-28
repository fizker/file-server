import EnvironmentVariables
import Vapor

enum EnvVar: String, CaseIterable {
	case uploadFolder = "upload-folder"
}

extension EnvironmentVariables where Key == EnvVar {
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
