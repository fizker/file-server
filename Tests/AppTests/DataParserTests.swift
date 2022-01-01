@testable import App
import XCTest

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
}
