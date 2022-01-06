import Vapor

struct MultipartRequest {
	struct File {
		var contentType: String
		var filename: String
		var file: StreamFile
	}

	struct Header {
		var name: String
		var value: String
		var properties: [String: String]

		func `is`(_ value: String) -> Bool {
			value.lowercased() == name.lowercased()
		}
	}

	enum Content {
		case file(File)
		case value(String)
	}

	struct Value {
		var contentDisposition: Header
		var name: String
		var headers: [Header]
		var content: Content

		func header(named name: String) -> Header? {
			headers.first { $0.is(name) }
		}
	}

	var values: [Value]

	func value(named name: String) -> Value? {
		values.first { $0.name == name }
	}
}

actor MultipartHandler {
	enum Error: Swift.Error {
		case invalidContentType
		case boundaryMissing
		case invalidFormattedData
		case invalidHeader(String)
		case contentMissing
		case contentDispositionMissingFromValue
		case invalidContentDisposition(MultipartRequest.Header)
		case invalidContent(String)
	}

	let boundary: String
	// This should not exist, but the tests cannot compile if they try to read the let variable
	var testBoundary: String { boundary }

	var request: MultipartRequest?

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

	func parse(_ body: Request.Body, eventLoop: EventLoop) async throws -> MultipartRequest {
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

		return try parse(data)
	}

	func parse(_ data: Data) throws -> MultipartRequest {
		let parser = DataParser(data: data)

		guard
			let firstLine = try parser.readLine(),
			firstLine == "--\(boundary)"
		else { throw Error.invalidFormattedData }

		var request = MultipartRequest(values: [])

		var isComplete = false
		repeat {
			var headers: [MultipartRequest.Header] = []

			while true {
				guard let line = try parser.readLine()
				else { throw Error.invalidFormattedData }

				guard line != ""
				else { break }

				guard !line.hasPrefix("--\(boundary)")
				else { throw Error.contentMissing }

				let header = try parseHeader(from: line)

				headers.append(header)
			}

			guard let contentDisposition = headers.first(where: { $0.is("content-disposition") })
			else { throw Error.contentDispositionMissingFromValue }
			guard let name = contentDisposition.properties["name"]
			else { throw Error.invalidContentDisposition(contentDisposition) }

			let content: MultipartRequest.Content

			let contentType = headers.first { $0.is("content-type") }
			if contentType == nil {
				guard
					let data = parser.readData(until: "\n--\(boundary)".data(using: .utf8)!),
					let value = String(data: data, encoding: .utf8)
				else { throw Error.invalidContent(name) }
				content = .value(value)
			} else {
				fatalError("File not implemented")
			}

			request.values.append(.init(
				contentDisposition: contentDisposition,
				name: name,
				headers: headers,
				content: content
			))

			let remainingLine = try parser.readLine()
			isComplete = remainingLine == "--"
		} while !isComplete

		return request
	}

	func parseHeader(from line: String) throws -> MultipartRequest.Header {
		let data = line.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
		guard data.count == 2
		else { throw Error.invalidHeader(line) }

		let name = data[0]

		let s2 = data[1].components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
		let value = s2[0]

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

		return .init(name: name, value: value, properties: properties)
	}
}
