import Foundation
import Collections

class DataParser {
	enum Error: Swift.Error {
		case couldNotParseLine(Data)
	}

	let data: AsyncThrowingStream<UInt8, Swift.Error>
	var isFinished = false

	init(data: AsyncThrowingStream<UInt8, Swift.Error>) {
		self.data = data
	}

	convenience init(data: Data) {
		self.init(data: AsyncThrowingStream {
			for byte in data {
				$0.yield(byte)
			}
			$0.finish()
		})
	}

	func readLine(encoding: String.Encoding = .utf8) async throws -> String? {
		guard let stream = readData(until: "\n".data(using: .utf8)!.first!)
		else { return nil }

		let data = try await stream.asData

		guard let line = String(data: data, encoding: encoding)
		else { throw Error.couldNotParseLine(data) }

		return line
	}

	func readData(until boundary: UInt8) -> AsyncThrowingStream<UInt8, Swift.Error>? {
		guard !isFinished
		else { return nil }

		return AsyncThrowingStream {
			for try await byte in self.data {
				guard byte != boundary
				else { return nil }

				return byte
			}

			self.isFinished = true
			return nil
		}
	}

	func readData<T: Sequence>(until boundary: T) -> AsyncThrowingStream<UInt8, Swift.Error>?
		where T.Element == UInt8
	{
		guard !isFinished
		else { return nil }

		let boundary = Deque(boundary)

		guard !boundary.isEmpty
		else { return nil }

		var window = Deque<UInt8>()

		return AsyncThrowingStream {
			if window == boundary {
				return nil
			}

			for try await b in self.data {
				window.append(b)

				if window.count > boundary.count {
					return window.popFirst()
				}

				if window.count == boundary.count && window == boundary {
					return nil
				}
			}

			self.isFinished = true
			return window.popFirst()
		}
	}
}
