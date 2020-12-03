import Vapor

struct FileUpload: Decodable {
	var file: [File]
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
			<style>
				.file {
					display: block;
				}
			</style>
			<form method="post" action="/" enctype="multipart/form-data">
				<label class="file">
					File:
					<input type="file" name="file[]">
				</label>
				<label class="file">
					File:
					<input type="file" name="file[]">
				</label>
				<button type="submit">Upload</button>
			</form>
			"""
		)
	}

	app.post { req -> EventLoopFuture<String> in
		let dto = try req.content.decode(FileUpload.self)

		return EventLoopFuture.andAllComplete(dto.file.map { file -> EventLoopFuture<Void> in
			let path = "\(uploadFolder)/\(file.filename)"
			return req.fileio.writeFile(file.data, at: path)
		}, on: req.eventLoop.next())
		.map { "thanks" }
	}
}
