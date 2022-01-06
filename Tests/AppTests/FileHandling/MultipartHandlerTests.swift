@testable import App
import XCTest
import Vapor

func AssertEqual<T: Equatable>(_ expected: T, _ actual: T, file: StaticString = #file, line: UInt = #line) {
	XCTAssertEqual(expected, actual, file: file, line: line)
}
func AssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
	XCTAssertTrue(value, file: file, line: line)
}

final class FakeFileStream: FileStream {
	var data = Data()
	var isClosed = false

	func write(_ buffer: ByteBuffer) async throws {
		data.append(Data(buffer: buffer))
	}

	func close() async throws {
		isClosed = true
	}
}

extension MultipartHandler {
	convenience init(boundary: String) throws {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = boundary

		try self.init(contentType: contentType, fileStreamFactory: FakeFileStream.init)
	}
}

final class MultipartHandlerTests: XCTestCase {
	func test__init__contentTypeIsMultipartFormData_boundaryIsPresent__isInit() async throws {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = "foo"

		let subject = try MultipartHandler(contentType: contentType, fileStreamFactory: FakeFileStream.init)

		XCTAssertEqual("foo", await subject.testBoundary)
	}

	func test__parse__bodyHasTwoValues__valuesAreRead() async throws {
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

		XCTAssertEqual([
			"foo": "first content",
			"bar": """
			second content
			with multiple
			lines

			of content
			""",
		], values)

		XCTAssertFalse(hasFiles)
	}

	func test__parse__bodyDoesNotStartWithBoundary__throws() async throws {
		let boundary = "foobar"
		let input = """
		Content-Disposition: form-data; name="foo"

		first content
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		do {
			_ = try await subject.parse(input.data(using: .utf8)!)
			XCTFail("Should have thrown")
		} catch MultipartHandler.Error.invalidFormattedData {
			// Expected error
		} catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	func test__parse__bodyIsMissingFinalBoundary__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"

		first content
		"""

		let subject = try MultipartHandler(boundary: boundary)

		do {
			_ = try await subject.parse(input.data(using: .utf8)!)
			XCTFail("Should have thrown")
		} catch MultipartHandler.Error.invalidFormattedData {
			// Expected error
		} catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	func test__parse__contentIsMissing_headersAreFinished__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"

		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		do {
			_ = try await subject.parse(input.data(using: .utf8)!)
			XCTFail("Should have thrown")
		} catch MultipartHandler.Error.invalidFormattedData {
			// Expected error
		} catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	func test__parse__contentIsMissing_headersAreNotFinished__throws() async throws {
		let boundary = "foobar"
		let input = """
		--\(boundary)
		Content-Disposition: form-data; name="foo"
		--\(boundary)--
		"""

		let subject = try MultipartHandler(boundary: boundary)

		do {
			_ = try await subject.parse(input.data(using: .utf8)!)
			XCTFail("Should have thrown")
		} catch MultipartHandler.Error.contentMissing {
			// Expected error
		} catch {
			XCTFail("Unexpected error: \(error)")
		}
	}

	func test__parse__multipleHeaders__parsesAllHeaders() async throws {
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

		let value = request.value(named: "foo")
		XCTAssertNotNil(value)
		let customHeader = value?.header(named: "x-custom-header")
		XCTAssertNotNil(customHeader)
		XCTAssertEqual("foo bar baz", customHeader?.value)

		switch value?.content {
		case let .value(value):
			XCTAssertEqual("content", value)
		default:
			XCTFail("Incorrect content type")
		}
	}

	func test__parse__fileContent__createsAFile_fileGetsData() async throws {
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

		let value = request.value(named: "foo")
		XCTAssertNotNil(value)

		switch value?.content {
		case let .file(file):
			let fakeFile = file.file as? FakeFileStream
			XCTAssertEqual("application/json", file.contentType)
			XCTAssertEqual("""
			{
				"foo": "bar",
				"baz": 1
			}
			""".data(using: .utf8)!, fakeFile?.data)
		default:
			XCTFail("Incorrect content type")
		}
	}

	// This exists because @autoclosure does not work with async values, so the built-in XCTAssertEqual cannot be used to verify data on actors
	func XCTAssertEqual<T: Equatable>(_ expected: T, _ actual: T, file: StaticString = #file, line: UInt = #line) {
		AssertEqual(expected, actual, file: file, line: line)
	}
}
