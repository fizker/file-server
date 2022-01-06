import Foundation
import Collections

class DataParser {
	enum Error: Swift.Error {
		case couldNotParseLine(Data)
	}

	let data: AsyncStream<UInt8>
	var isFinished = false

	init(data: AsyncStream<UInt8>) {
		self.data = data
	}

	convenience init(data: Data) {
		self.init(data: AsyncStream {
			for byte in data {
				$0.yield(byte)
			}
			$0.finish()
		})
	}

	func readLine(encoding: String.Encoding = .utf8) async throws -> String? {
		guard let stream = readData(until: "\n".data(using: .utf8)!.first!)
		else { return nil }

		let data = await stream.asData

		guard let line = String(data: data, encoding: encoding)
		else { throw Error.couldNotParseLine(data) }

		return line
	}

	func readData(until boundary: UInt8) -> AsyncStream<UInt8>? {
		guard !isFinished
		else { return nil }

		return AsyncStream {
			for await byte in self.data {
				guard byte != boundary
				else { return nil }

				return byte
			}

			self.isFinished = true
			return nil
		}
	}

	func readData<T: Sequence>(until boundary: T) -> AsyncStream<UInt8>?
		where T.Element == UInt8
	{
		guard !isFinished
		else { return nil }

		let boundary = Deque(boundary)

		guard !boundary.isEmpty
		else { return nil }

		var window = Deque<UInt8>()

		return AsyncStream {
			if window == boundary {
				return nil
			}

			for await b in self.data {
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
