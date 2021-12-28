import Vapor

// configures your application
public func configure(_ app: Application) throws {
	app.envVars = .init(valueGetter: Environment.get(_:))
	try app.envVars.assertKeys()

	// uncomment to serve files from /Public folder
	// app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	// register routes
	try routes(app)
}
