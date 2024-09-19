@testable import App
import Foundation
import Testing

func read(stream: AsyncThrowingStream<UInt8, Error>?, encoding: String.Encoding) async throws -> String? {
	return read(data: try await stream?.asData, encoding: encoding)
}

func read(data: Data?, encoding: String.Encoding) -> String? {
	return data.flatMap { String(data: $0, encoding: encoding) }
}

struct DataParserTests {
	@Test
	func readLine__multipleLines__returnsTheLine() async throws {
		let input = """
		foo
		bar
		baz
		"""

		let subject = DataParser(data: input.data(using: .utf8)!)

		let line1 = try await subject.readLine()
		#expect("foo" == line1)
		let line2 = try await subject.readLine()
		#expect("bar" == line2)
		let line3 = try await subject.readLine()
		#expect("baz" == line3)
		let line4 = try await subject.readLine()
		#expect(line4 == nil)
	}

	@Test
	func readData__multiByteBoundary__returnsTheData() async throws {
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

		let firstActual = try await read(stream: subject.readData(until: "foobar".data(using: .utf8)!), encoding: .utf8)
		#expect("\(firstPart)\n" == firstActual)

		let secondActual = try await read(stream: subject.readData(until: "foobar".data(using: .utf8)!), encoding: .utf8)
		#expect("\n\(secondPart)\n" == secondActual)

		let thirdActual = try await read(stream: subject.readData(until: "foobar".data(using: .utf8)!), encoding: .utf8)
		#expect("\n\(thirdPart)" == thirdActual)

		#expect(subject.readData(until: "foobar".data(using: .utf8)!) == nil)
	}
}
