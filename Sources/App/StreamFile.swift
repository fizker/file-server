import Foundation
import NIOCore
import Vapor

actor StreamFile {
	enum Error: Swift.Error {
		case alreadyClosed
		case existingFileAtPath
	}

	private let tempPath = "/tmp/file-upload-\(UUID().uuidString)"
	private let tempURL: URL
	private var handle: NIOFileHandle?
	private var req: Request
	private let fm = FileManager.default

	var path: URL?

	init(req: Request) async throws {
		self.req = req
		tempURL = URL(fileURLWithPath: tempPath)
		try Data().write(to: tempURL)

		handle = try await req.application.fileio.openFile(
			path: tempPath,
			mode: [ .read, .write ],
			eventLoop: req.eventLoop.next()
		).get()
	}

	func setPath(_ path: String) throws {
		try setPath(URL(fileURLWithPath: path))
	}

	func setPath(_ path: URL) throws {
		self.path = path
		if fm.fileExists(atPath: path.path) {
			throw Error.existingFileAtPath
		}
	}

	func write(_ data: Data) async throws {
		let buffer = ByteBuffer(data: data)
		try await write(buffer)
	}

	func write(_ buffer: ByteBuffer) async throws {
		guard let handle = handle
		else { throw Error.alreadyClosed }

		try await req.application.fileio.write(
			fileHandle: handle,
			buffer: buffer,
			eventLoop: req.eventLoop.next()
		).get()
	}

	func close() throws {
		try handle?.close()
		handle = nil

		if let path = path {
			try fm.moveItem(at: URL(fileURLWithPath: tempPath), to: path)
		}
		path = nil
	}

	deinit {
		do {
			try close()
		} catch {
			print("Failed to close")
		}
	}
}
