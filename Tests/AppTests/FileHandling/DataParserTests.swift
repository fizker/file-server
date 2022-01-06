@testable import App
import XCTest

func XCTAssertEqual(_ expected: String, _ actual: AsyncStream<UInt8>?, encoding: String.Encoding, file: StaticString = #file, line: UInt = #line) async {
	XCTAssertEqual(expected, await actual?.asData, encoding: encoding, file: file, line: line)
}

func XCTAssertEqual(_ expected: String, _ actual: Data?, encoding: String.Encoding, file: StaticString = #file, line: UInt = #line) {
	XCTAssertEqual(expected, actual.flatMap { String(data: $0, encoding: encoding) }, file: file, line: line)
}

final class DataParserTests: XCTestCase {
	func test__readLine__multipleLines__returnsTheLine() async throws {
		let input = """
		foo
		bar
		baz
		"""

		let subject = DataParser(data: input.data(using: .utf8)!)

		let line1 = try await subject.readLine()
		XCTAssertEqual("foo", line1)
		let line2 = try await subject.readLine()
		XCTAssertEqual("bar", line2)
		let line3 = try await subject.readLine()
		XCTAssertEqual("baz", line3)
		let line4 = try await subject.readLine()
		XCTAssertNil(line4)
	}

	func test__readData__multiByteBoundary__returnsTheData() async throws {
		let firstPart = """
		foo
		bar
		"""
		let secondPart = """
		bar
		baz
		"""
		let thirdPart = """
		fifum
		"""
		let input = """
		\(firstPart)
		foobar
		\(secondPart)
		foobar
		\(thirdPart)
		"""

		let subject = DataParser(data: input.data(using: .utf8)!)

		await XCTAssertEqual(
			"\(firstPart)\n",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		await XCTAssertEqual(
			"\n\(secondPart)\n",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		await XCTAssertEqual(
			"\n\(thirdPart)",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		XCTAssertNil(subject.readData(until: "foobar".data(using: .utf8)!))
	}
}
