import Foundation
import NIOCore
import Vapor

protocol FileStream {
	var path: String { get }
	var url: URL { get }
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

	let path = "/tmp/file-upload-\(UUID().uuidString)"
	let url: URL
	let bufferSize: Int
	private var handle: NIOFileHandle?
	private var req: Request

	init(req: Request, bufferSize: Int = 1_000_000) async throws {
		self.req = req
		self.bufferSize = bufferSize
		url = URL(fileURLWithPath: path)
		try Data().write(to: url)

		handle = try await req.application.fileio.openFile(
			path: path,
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
			if data.count > bufferSize {
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
