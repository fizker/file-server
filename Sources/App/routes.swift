import Vapor

struct FileUpload: Decodable {
	var file: File
}

enum ConfigurationError: Error {
	case uploadFolderMissing
}

func routes(_ app: Application) throws {
	guard let uploadFolder = Environment.get("upload-folder")
	else { throw ConfigurationError.uploadFolderMissing }

	app.get { req in
		return Response(
			headers: ["content-type": "text/html"],
			body: """
			<!doctype html>
			<title>Upload files</title>
			<form method="post" action="/upload" enctype="multipart/form-data">
				<label>
					File:
					<input type="file" name="file">
				</label>
				<br>
				<button type="submit">Upload</button>
			</form>
			"""
		)
	}

	app.post("upload") { req -> EventLoopFuture<String> in
		let dto = try req.content.decode(FileUpload.self)

		let path = "\(uploadFolder)/\(dto.file.filename)"

		return req.fileio.writeFile(dto.file.data, at: path)
		.map { "thanks" }
	}
}
