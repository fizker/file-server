import Vapor

extension AsyncStream where Element == UInt8 {
	var asData: Data {
		get async {
			var data = Data()
			for await byte in self {
				data.append(byte)
			}
			return data
		}
	}
}

struct MultipartRequest {
	struct File {
		var contentType: String
		var file: FileStream
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
	typealias FileStreamFactory = () -> FileStream
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

	let fileStreamFactory: FileStreamFactory
	let boundary: String
	// This should not exist, but the tests cannot compile if they try to read the let variable
	var testBoundary: String { boundary }

	var request: MultipartRequest?

	init(contentType: HTTPMediaType, fileStreamFactory: @escaping FileStreamFactory) throws {
		self.fileStreamFactory = fileStreamFactory

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

		return try await parse(data)
	}

	func parse(_ data: Data) async throws -> MultipartRequest {
		let parser = DataParser(data: data)

		guard
			let firstLine = try await parser.readLine(),
			firstLine == "--\(boundary)"
		else { throw Error.invalidFormattedData }

		var request = MultipartRequest(values: [])

		var isComplete = false
		repeat {
			var headers: [MultipartRequest.Header] = []

			while true {
				guard let line = try await parser.readLine()
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
			if let contentType = contentType {
				let file = fileStreamFactory()
				content = .file(.init(
					contentType: contentType.value,
					file: file
				))
				guard let stream = parser.readData(until: "\n--\(boundary)".data(using: .utf8)!)
				else { throw Error.invalidContent(name) }
				let data = await stream.asData
				try await file.write(data)
			} else {
				guard
					let stream = parser.readData(until: "\n--\(boundary)".data(using: .utf8)!),
					let value = String(data: await stream.asData, encoding: .utf8)
				else { throw Error.invalidContent(name) }
				content = .value(value)
			}

			request.values.append(.init(
				contentDisposition: contentDisposition,
				name: name,
				headers: headers,
				content: content
			))

			let remainingLine = try await parser.readLine()
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
