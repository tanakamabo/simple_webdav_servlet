# simple_webdav_servlet
A simple WebDAV servlet class for Local disk storage.This class is intended to be modified directly such as local base directory path(BASE_PATH field),WebDAV user accounts(accounts field), servlet mapping(WebServlet annotation) and Web UI for practical use.This servlet can be used from Web browsers and WebDAV clients for normal use since it supports only OPTIONS, GET, HEAD, PUT, DELETE, MKCOL methods.This servlet is only tested on Windows, but this generalizes file path delimiters and may work easily other operating systems.

## Quick Start
This source code is intended to be build with Eclipse IDE.
Please clone this repository inside an Eclipse workspace directory and import the simple_webdav_servlet project.
Open the SimpleWebDAVServlet.java file with editor and modify BASE_PATH with a certain directory.
Then add the project to Tomcat9.0 server in eclipse, launch Tomcat with any port such as 8080.
Access this URL http://localhost:8080/simple_webdav_servlet/SimpleWebDAVServlet/ with Web browser or WebDAV client.
Login with default a user account either user1/pass1 or user2/pass2 and you can see the local files from WebDAV view.

## How to Import SimpleWebDAVServlet to Other Web Apps
Just copy SimpleWebDAVServlet.java to other Java Web applications and make it work. This servlet class does not require any third party libraries.
