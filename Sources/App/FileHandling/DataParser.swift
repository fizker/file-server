import Foundation
import Collections

class DataParser {
	enum Error: Swift.Error {
		case couldNotParseLine(Data)
	}

	let data: Data
	var currentIndex: Data.Index?

	init(data: Data) {
		self.data = data
		currentIndex = data.startIndex
	}

	func readLine(encoding: String.Encoding = .utf8) throws -> String? {
		guard let data = readData(until: "\n".data(using: .utf8)!.first!)
		else { return nil }

		guard let line = String(data: data, encoding: encoding)
		else { throw Error.couldNotParseLine(data) }

		return line
	}

	func readData(until boundary: UInt8) -> Data? {
		guard let currentIndex = currentIndex
		else { return nil }

		let index = data[currentIndex...].firstIndex(of: boundary) ?? data.endIndex

		if index == data.endIndex {
			self.currentIndex = nil
		} else {
			self.currentIndex = data.index(after: index)
		}

		return data[currentIndex..<index]
	}

	func readData<T: Sequence>(until boundary: T) -> Data?
		where T.Element == UInt8
	{
		guard let currentIndex = currentIndex
		else { return nil }

		let boundary = Deque(boundary)

		guard !boundary.isEmpty
		else { return nil }

		var window = Deque<UInt8>()
		var index = currentIndex

		for b in data[index...] {
			window.append(b)
			if window.count > boundary.count {
				_ = window.popFirst()
				index = data.index(after: index)
			}

			if window == boundary {
				self.currentIndex = data.index(index, offsetBy: boundary.count)
				return data[currentIndex..<index]
			}
		}

		self.currentIndex = nil
		return data[currentIndex...]
	}
}
