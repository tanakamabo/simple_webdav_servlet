# simple_webdav_servlet
A simple WebDAV servlet class for Local disk storage.This class is intended to be modified directly such as local base directory path(BASE_PATH field),WebDAV user accounts(accounts field), servlet mapping(WebServlet annotation) and Web UI for practical use.This servlet can be used from Web browsers and WebDAV clients for normal use since it supports only OPTIONS, GET, HEAD, PUT, DELETE, MKCOL methods.This servlet is only tested on Windows, but this generalizes file path delimiters and may work easily other operating systems.
