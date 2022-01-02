@testable import App
import XCTest

func XCTAssertEqual(_ expected: String, _ actual: Data?, encoding: String.Encoding, file: StaticString = #file, line: UInt = #line) {
	XCTAssertEqual(expected, actual.flatMap { String(data: $0, encoding: encoding) }, file: file, line: line)
}

final class DataParserTests: XCTestCase {
	func test__readLine__multipleLines__returnsTheLine() throws {
		let input = """
		foo
		bar
		baz
		"""

		let subject = DataParser(data: input.data(using: .utf8)!)

		XCTAssertEqual("foo", try subject.readLine())
		XCTAssertEqual("bar", try subject.readLine())
		XCTAssertEqual("baz", try subject.readLine())
		XCTAssertNil(try subject.readLine())
	}

	func test__readData__multiByteBoundary__returnsTheData() throws {
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

		XCTAssertEqual(
			"\(firstPart)\n",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		XCTAssertEqual(
			"\n\(secondPart)\n",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		XCTAssertEqual(
			"\n\(thirdPart)",
			subject.readData(until: "foobar".data(using: .utf8)!),
			encoding: .utf8
		)
		XCTAssertNil(subject.readData(until: "foobar".data(using: .utf8)!))
	}
}
