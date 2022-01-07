import Foundation
import NIOCore
import Vapor

protocol FileStream {
	var filePath: String { get }
	var fileURL: URL { get }
	func write(_ stream: AsyncThrowingStream<UInt8, Error>) async throws
	func close() async throws
}
extension FileStream {
	func write(_ buffer: ByteBuffer) async throws {
		try await write(Data(buffer: buffer))
	}

	func write(_ byte: UInt8) async throws {
		let buffer = ByteBuffer(bytes: [byte])
		try await write(buffer)
	}

	func write(_ data: Data) async throws {
		try await write(AsyncThrowingStream {
			for byte in data {
				$0.yield(byte)
			}
			$0.finish()
		})
	}
}

actor StreamFile: FileStream {
	enum Error: Swift.Error {
		case alreadyClosed
		case existingFileAtPath
	}

	let filePath = "/tmp/file-upload-\(UUID().uuidString)"
	let fileURL: URL
	private var handle: NIOFileHandle?
	private var req: Request

	init(req: Request) async throws {
		self.req = req
		fileURL = URL(fileURLWithPath: filePath)
		try Data().write(to: fileURL)

		handle = try await req.application.fileio.openFile(
			path: filePath,
			mode: [ .read, .write ],
			eventLoop: req.eventLoop.next()
		).get()
	}

	func write(_ stream: AsyncThrowingStream<UInt8, Swift.Error>) async throws {
		guard let handle = handle
		else { throw Error.alreadyClosed }

		func write(_ data: Data) async throws {
			let buffer = ByteBuffer(data: data)

			try await req.application.fileio.write(
				fileHandle: handle,
				buffer: buffer,
				eventLoop: req.eventLoop.next()
			).get()
		}

		var data = Data()
		for try await byte in stream {
			data.append(byte)
			if data.count > 1023 {
				try await write(data)
				data = Data()
			}
		}
		try await write(data)
	}

	func close() async throws {
		try _close()
	}

	func _close() throws {
		try handle?.close()
		handle = nil
	}

	deinit {
		do {
			try _close()
		} catch {
			print("Failed to close")
		}
	}
}
