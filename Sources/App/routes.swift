import Vapor
import Foundation

struct FileUpload: Decodable {
	var file: [File]
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

	app.on(.POST, body: .stream) { req -> String in
		guard let contentType = req.content.contentType
		else { return "error content type missing" }

		let handler = try MultipartHandler(
			contentType: contentType,
			fileStreamFactory: { try await StreamFile(req: req) }
		)

		let multipartRequest = try await handler.parse(req.body, eventLoop: req.eventLoop)

		let fm = FileManager.default
		let basePath = URL(fileURLWithPath: uploadFolder + "/")

		for value in multipartRequest.values {
			switch value.content {
			case let .file(file):
				guard
					let filename = value.contentDisposition.properties["filename"],
					!filename.isEmpty
				else { continue }

				let resultPath = basePath.appendingPathComponent(filename)
				try? fm.removeItem(at: resultPath)
				try fm.moveItem(at: file.temporaryURL, to: resultPath)
			case .value(_):
				break
			}
		}

		return "thanks"
	}
}
