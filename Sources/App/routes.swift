import Vapor

struct FileUpload: Decodable {
	var file: File
	var foo: String
}

enum ConfigurationError: Error {
	case uploadFolderMissing
}

func routes(_ app: Application) throws {
	guard let uploadFolder = Environment.get("upload-folder")
	else { throw ConfigurationError.uploadFolderMissing }

	app.get { req in
		return "It works!"
	}

	app.get("hello") { req -> String in
		return "Hello, world!"
	}

	app.post("file") { req -> EventLoopFuture<String> in
		let dto = try req.content.decode(FileUpload.self)

		let path = "\(uploadFolder)/\(dto.file.filename)"

		return req.fileio.writeFile(dto.file.data, at: path)
		.map { "thanks" }
	}
}
