import Vapor

actor MultipartHandler {
	enum Error: Swift.Error {
		case invalidContentType
		case boundaryMissing
		case invalidFormattedData
	}

	var values: [String: String] = [:]
	var files: [(contentType: String, filename: String, file: StreamFile)] = []

	let boundary: String
	// This should not exist, but the tests cannot compile if they try to read the let variable
	var testBoundary: String { boundary }

	init(contentType: HTTPMediaType) throws {
		switch (contentType.type, contentType.subType) {
		case ("multipart", "form-data"):
			guard let boundary = contentType.parameters["boundary"]
			else { throw Error.boundaryMissing }
			self.boundary = boundary
		default:
			throw Error.invalidContentType
		}
	}

	func parse(_ body: Request.Body, eventLoop: EventLoop) async throws {
		let data: Data = try await withCheckedThrowingContinuation({ c in
			var data = Data()

			body.drain { (body: BodyStreamResult) in
				switch body {
				case .end:
					c.resume(returning: data)
				case let .error(error):
					c.resume(throwing: error)
				case let .buffer(buffer):
					let d = Data(buffer: buffer)
					data.append(d)
				}

				return eventLoop.future()
			}
		})

		try parse(data)
	}

	func parse(_ data: Data) throws {
		let parser = DataParser(data: data)

		guard
			let firstLine = try parser.readLine(),
			firstLine == "--\(boundary)"
		else { throw Error.invalidFormattedData }

		var isComplete = false
		repeat {
			guard let line = try parser.readLine()
			else { throw Error.invalidFormattedData }

			let metadata = try parse(line: line)

			// There should be an empty line between content and the segment headers
			guard try parser.readLine() == ""
			else { throw Error.invalidFormattedData }

			if metadata.contentType == nil {
				guard let data = parser.readData(until: "\n--\(boundary)".data(using: .utf8)!)
				else { throw Error.invalidFormattedData }
				values[metadata.name] = String(data: data, encoding: .utf8)
			} else {
				// handle file
			}

			let remainingLine = try parser.readLine()
			isComplete = remainingLine == "--"
		} while !isComplete
	}

	struct Metadata {
		var contentDisposition: String
		var name: String
		var contentType: String?
	}

	func parse(line: String) throws -> Metadata {
		let data = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
		guard data[0].lowercased() == "content-disposition"
		else { fatalError("Unexpected line") }

		let s2 = data[1].components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }

		guard s2[0] == "form-data"
		else { fatalError("Line formatted incorrectly") }

		let kvPairs: [(String, String)] = s2[1...].map {
			let pairs = $0.components(separatedBy: "=")
				.map { $0.trimmingCharacters(in: .whitespaces) }
			guard pairs.count == 2
			else { fatalError("Invalid key-value pair") }
			let key = pairs[0]
			let value = pairs[1].trimmingCharacters(in: .init(charactersIn: "\""))
			return (key, value)
		}
		let properties = Dictionary(uniqueKeysWithValues: kvPairs)

		guard let name = properties["name"]
		else { fatalError("Name of property missing") }

		return .init(contentDisposition: s2[0], name: name, contentType: nil)
	}
}
