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
		app.on(.POST, "test-echo", body: .stream) { req -> String in
			let data = try await withCheckedThrowingContinuation({ (c: CheckedContinuation<Data, Error>) in
				var data = Data()

				req.body.drain { (body: BodyStreamResult) in
					switch body {
					case .end:
						c.resume(returning: data)
					case let .error(error):
						c.resume(throwing: error)
					case let .buffer(buffer):
						let d = Data(buffer: buffer)
						data.append(d)
					}

					return req.eventLoop.future()
				}
			})

			let content = String(data: data, encoding: .utf8)!
			return content
		}

		app.on(.POST, "test", body: .stream) { req -> String in
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
					else {
						try await file.file.close()
						continue
					}

					let resultPath = basePath.appendingPathComponent(filename)
					try? fm.removeItem(at: resultPath)
					try fm.moveItem(at: file.file.fileURL, to: resultPath)
					try await file.file.close()
				case .value(_):
					break
				}
			}

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
