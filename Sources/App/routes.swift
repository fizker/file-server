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
				<button type="submit">Upload</button>
			</form>

			<script>
				function addFile(event) {
					const form = document.querySelector("form")
					const button = form.querySelector("form > button")

					const div = document.createElement("div")
					div.className = "file"

					const input = document.createElement("input")
					div.appendChild(input)
					input.name = "file[]"
					input.type = "file"
					input.onchange = addFile

					form.insertBefore(div, button)

					if(event == null) {
						return
					}

					const currentElement = event.currentTarget
					if(currentElement.nextElementSibling == null) {
						const container = currentElement.parentElement

						const removeButton = document.createElement("button")
						removeButton.innerHTML = "Remove file"
						removeButton.onclick = () => {
							container.remove()
						}
						container.appendChild(removeButton)
					}
				}

				addFile()
			</script>
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
