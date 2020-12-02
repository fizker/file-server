import Vapor

struct FileUpload: Decodable {
	var file: File
	var foo: String
}

func routes(_ app: Application) throws {
	app.get { req in
		return "It works!"
	}

	app.get("hello") { req -> String in
		return "Hello, world!"
	}

	app.post("file") { req -> String in
		let dto = try req.content.decode(FileUpload.self)
		return "\(dto.file.filename): \(dto.file.data.readableBytes)"
	}
}
