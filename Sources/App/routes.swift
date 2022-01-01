import Vapor
import Foundation

struct FileUpload: Decodable {
	var file: [File]
}

enum ConfigurationError: Error {
	case uploadFolderMissing
}

func routes(_ app: Application) throws {
	let uploadFolder = try app.envVars.uploadFolder

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

	if #available(macOS 12, *) {
		app.on(.POST, "test", body: .stream) { req -> String in
			let file = try await StreamFile(req: req)
			let path = "/Users/benjamin/Development/own/file-server/temp123"
			try await file.setPath(path)

			func write(_ value: String) async throws {
				let data = value.data(using: .utf8)!
				try await file.write(data)
			}

			try await write("foo")
			try await write("bar")

			try await file.close()

			return "finished"
		}
	}

	app.on(.POST, body: .collect(maxSize: app.envVars.maxUploadSize)) { req -> EventLoopFuture<String> in
		let dto = try req.content.decode(FileUpload.self)

		return EventLoopFuture.andAllComplete(dto.file.map { file -> EventLoopFuture<Void> in
			let path = "\(uploadFolder)/\(file.filename)"
			return req.fileio.writeFile(file.data, at: path)
		}, on: req.eventLoop.next())
		.map { "thanks" }
	}
}
