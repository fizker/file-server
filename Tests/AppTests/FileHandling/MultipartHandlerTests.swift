@testable import App
import Testing
import Vapor

final class FakeFileStream: FileStream {
	var data = Data()
	var isClosed = false
	let url = URL(fileURLWithPath: "/\(UUID())")
	var path: String { url.absoluteString }

	func write(_ stream: AsyncThrowingStream<UInt8, Swift.Error>) async throws {
		data.append(try await stream.asData)
	}

	func close() async throws {
		isClosed = true
	}
}

final class MultipartHandlerTests {
	var files: [URL: FakeFileStream] = [:]

	func MultipartHandler(boundary: String) throws -> MultipartHandler {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = boundary

		return try App.MultipartHandler(contentType: contentType, fileStreamFactory: {
			let stream = FakeFileStream()
			self.files[stream.url] = stream
			return stream
		})
	}

	@Test
	func init__contentTypeIsMultipartFormData_boundaryIsPresent__isInit() async throws {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = "foo"

		let subject = try App.MultipartHandler(contentType: contentType, fileStreamFactory: FakeFileStream.init)

		let testBoundary = await subject.testBoundary
		#expect("foo" == testBoundary)
	}

	@Test
	func parse__bodyHasTwoValues__valuesAreRead() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"

		first content
		--\(boundary)
		Content-Disposition: form-data; name="bar"

		second content
		with multiple
		lines

		of content
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		let request = try await subject.parse(input.data(using: .utf8)!)

		var hasFiles = false
		var values: [String: String] = [:]

		for value in request.values {
			switch value.content {
			case let .value(content):
				values[value.name] = content
			case .file(_):
				hasFiles = true
			}
		}

		#expect([
			"foo": "first content",
			"bar": """
			second content
			with multiple
			lines

			of content
			""",
		] == values)

		#expect(hasFiles == false)
	}

	@Test
	func parse__bodyDoesNotStartWithBoundary__throws() async throws {
		let boundary = "foobar"
		let input = """
		Content-Disposition: form-data; name="foo"

		first content
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		await #expect(throws: App.MultipartHandler.Error.invalidFormattedData.self) {
			_ = try await subject.parse(input.data(using: .utf8)!)
		}
	}

	@Test
	func parse__bodyIsMissingFinalBoundary__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"

		first content
		"""

		let subject = try MultipartHandler(boundary: boundary)

		await #expect(throws: App.MultipartHandler.Error.invalidFormattedData.self) {
			_ = try await subject.parse(input.data(using: .utf8)!)
		}
	}

	@Test
	func parse__contentIsMissing_headersAreFinished__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"

		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		await #expect(throws: App.MultipartHandler.Error.invalidFormattedData.self) {
			try await subject.parse(input.data(using: .utf8)!)
		}
	}

	@Test
	func parse__contentIsMissing_headersAreNotFinished__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		await #expect(throws: App.MultipartHandler.Error.contentMissing.self) {
			try await subject.parse(input.data(using: .utf8)!)
		}
	}

	@Test
	func parse__multipleHeaders__parsesAllHeaders() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"
		X-Custom-Header: foo bar baz

		content
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)
		let request = try await subject.parse(input.data(using: .utf8)!)

		let value = try #require(request.value(named: "foo"))
		let customHeader = try #require(value.header(named: "x-custom-header"))
		#expect("foo bar baz" == customHeader.value)

		#expect(.value("content") == value.content)
	}

	@Test
	func parse__fileContent__createsAFile_fileGetsData() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"
		content-type: application/json

		{
			"foo": "bar",
			"baz": 1
		}
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)
		let request = try await subject.parse(input.data(using: .utf8)!)

		let value = try #require(request.value(named: "foo"))

		switch value.content {
		case let .file(file):
			let fakeFile = files[file.temporaryURL]
			#expect("application/json" == file.contentType)
			#expect("""
			{
				"foo": "bar",
				"baz": 1
			}
			""".data(using: .utf8)! == fakeFile?.data)
		default:
			Issue.record("Incorrect content type")
		}
	}

	@Test
	func parse__bodyHasTwoValues_headersAreUsingCRLF__valuesAreRead() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)\r
		Content-Disposition: form-data; name="foo"\r
		\r
		first content
		--\(boundary)\r
		Content-Disposition: form-data; name="bar"\r
		\r
		second content
		with multiple
		lines

		of content
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		let request = try await subject.parse(input.data(using: .utf8)!)

		var hasFiles = false
		var values: [String: String] = [:]

		for value in request.values {
			switch value.content {
			case let .value(content):
				values[value.name] = content
			case .file(_):
				hasFiles = true
			}
		}

		#expect([
			"foo": "first content",
			"bar": """
			second content
			with multiple
			lines

			of content
			""",
		] == values)

		#expect(hasFiles == false)
	}
}
