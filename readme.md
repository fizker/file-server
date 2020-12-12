file-server
===========

A simple upload-file-server in Swift/Vapor.


## To run in docker

1. Clone the repo
2. Have at least docker engine 19+ installed.
3. Do `docker-compose build`
4. When it is built, `docker-compose up -d` creates the server.
5. Access it on port 8080 in your browser.
6. Uploaded files are placed in the `./upload` folder in the repo. Duplicates are overridden.
