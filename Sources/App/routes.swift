import Vapor
import Foundation

struct FileUpload: Decodable {
	var file: [File]
}

func routes(_ app: Application) throws {
	let uploadFolder = try app.envVars.uploadFolder

	app.get { req -> Response in
		let message = try? req.query.get(String.self, at: "m")

		return Response(
			headers: ["content-type": "text/html"],
			body: .init(string: """
			<!doctype html>
			<meta name="viewport" content="width=device-width, initial-scale=1">
			<title>Upload files</title>
			<style>
				.file {
					display: block;
				}
			</style>

			\(message.map({ """
				<div>
					\($0)
				</div>
				""" }) ?? "")

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
			""")
		)
	}

	app.on(.POST, body: .stream) { req -> Response in
		guard let contentType = req.content.contentType
		else { return req.redirect(to: "/?m=error content type missing") }

		let handler = try MultipartHandler(
			contentType: contentType,
			fileStreamFactory: { try await StreamFile(req: req) }
		)

		let multipartRequest = try await handler.parse(req.body, eventLoop: req.eventLoop)

		let fm = FileManager.default
		let basePath = URL(fileURLWithPath: uploadFolder + "/")

		var fileCount = 0

		for value in multipartRequest.values {
			switch value.content {
			case let .file(file):
				guard
					let filename = value.contentDisposition.properties["filename"],
					!filename.isEmpty
				else { continue }

				fileCount += 1

				let resultPath = basePath.appendingPathComponent(filename)
				try? fm.removeItem(at: resultPath)
				try fm.moveItem(at: file.temporaryURL, to: resultPath)
			case .value(_):
				break
			}
		}

		let message: String
		switch fileCount {
		case 0:
			message = "No files submitted"
		default:
			message = "File\(fileCount == 1 ? "" : "s") uploaded"
		}

		return req.redirect(to: "/?m=\(message)")
	}
}
