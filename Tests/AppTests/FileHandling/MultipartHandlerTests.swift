@testable import App
import XCTest
import Vapor

func AssertEqual<T: Equatable>(_ expected: T, _ actual: T, file: StaticString = #file, line: UInt = #line) {
	XCTAssertEqual(expected, actual, file: file, line: line)
}
func AssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
	XCTAssertTrue(value, file: file, line: line)
}

extension MultipartHandler {
	convenience init(boundary: String) throws {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = boundary

		try self.init(contentType: contentType)
	}
}

final class MultipartHandlerTests: XCTestCase {
	func test__init__contentTypeIsMultipartFormData_boundaryIsPresent__isInit() async throws {
		var contentType = HTTPMediaType(type: "multipart", subType: "form-data")
		contentType.parameters["boundary"] = "foo"

		let subject = try MultipartHandler(contentType: contentType)

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

		try await subject.parse(input.data(using: .utf8)!)

		XCTAssertEqual([
			"foo": "first content",
			"bar": """
			second content
			with multiple
			lines

			of content
			""",
		], await subject.values)

		XCTAssertTrue(await subject.files.isEmpty)
	}

	func XCTAssertEqual<T: Equatable>(_ expected: T, _ actual: T, file: StaticString = #file, line: UInt = #line) {
		AssertEqual(expected, actual, file: file, line: line)
	}
	func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) {
		AssertTrue(value, file: file, line: line)
	}
}
