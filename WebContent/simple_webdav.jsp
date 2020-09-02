<%@page import="webdav.SimpleWebDAVServlet"%>
<%
/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
%>
<%@page import="java.io.FileInputStream"%>
<%@page import="java.nio.file.DirectoryIteratorException"%>
<%@page import="java.util.Date"%>
<%@page import="java.nio.file.attribute.BasicFileAttributes"%>
<%@page import="java.nio.file.Files"%>
<%@page import="java.nio.file.DirectoryStream"%>
<%@page import="java.util.Locale"%>
<%@page import="java.text.SimpleDateFormat"%>
<%@page import="java.io.PrintWriter"%>
<%@page import="java.io.FileOutputStream"%>
<%@page import="java.nio.file.Path"%>
<%@page import="java.io.File"%>
<%@page import="java.nio.charset.Charset"%>
<%@page import="java.net.URLDecoder"%>
<%@page import="java.io.OutputStream"%>
<%@page import="java.io.InputStream"%>
<%@page import="java.io.ByteArrayOutputStream"%>
<%@page import="java.util.Base64"%>
<%@page import="java.io.IOException"%>
<%@page import="java.util.Set"%>
<%@page import="java.util.Arrays"%>
<%@page import="java.util.HashSet"%>
<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%
/**
 * A simple WebDAV servlet jsp file for Local disk storage. This file is made from SimpleWebDAVServlet but it is independent of the class in terms of this file's portability.
 * This jsp file needs to be invoked with a certain path defined in web.xml since jsp file cannot receive path parameter like php.
 * This class is intended to be modified directly such as local base directory path(BASE_PATH field), 
 * WebDAV user accounts(accounts field), servlet mapping(WebServlet annotation) and Web UI for practical use.
 * This servlet can be used from Web browsers and WebDAV clients for normal use since it supports only OPTIONS, GET, HEAD, PUT, DELETE, MKCOL methods.
 * This servlet is only tested on Windows, but this generalizes file path delimiters and may work easily other operating systems.
 * @author tanakamabo
 */
class SimpleWebDAVServlet extends HttpServlet {
	final long serialVersionUID = 1L;
	/**
	 * Base path of target disk. The default value must be changed.
	 */
	final String BASE_PATH = "C:\\mustchange";
	/**
	 * Account list of this WebDAV service. 
	 */
	Set<String> accounts = new HashSet<String>(Arrays.asList(
			"user1:pass1",
			"user2:pass2"
			));
	
    /**
     * @see HttpServlet#HttpServlet()
     */
    public SimpleWebDAVServlet() {
        super();
    }

    @Override
	protected void service(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
	    String enc = "UTF-8";
		boolean successedAuth = false;
		String auth = req.getHeader("Authorization");
		String user = null;
		String pass = null;
		if (auth != null && auth.startsWith("Basic")) {
			auth = auth.substring(5).trim();
			String up = new String(Base64.getDecoder().decode(auth.getBytes(enc)), enc);
			String[] splits = up.split(":", -1);
			if (splits.length == 2) {
				user = splits[0];
				pass = splits[1];
			}
		}
		// Authenticate
		successedAuth = authenticate(user, pass);

		if (successedAuth == false) {
			resp.setStatus(401);
			resp.setHeader("WWW-Authenticate", "Basic realm=\"EX\"");
			resp.setHeader("Content-Type", "text/html; charset=UTF-8");
			resp.getWriter().write(
					"<html><body><h1>Authorization Required</h1></body></html>");
			return;
		}

		if ("PROPFIND".equalsIgnoreCase(req.getMethod())) {
    		doPropfind(req, resp);
    		return;
    	}
		if ("MKCOL".equalsIgnoreCase(req.getMethod())) {
			doMkcol(req, resp);
			return;
		}
		if ("PUT".equalsIgnoreCase(req.getMethod())) {
			doPut(req, resp);
			return;
		}
		if ("DELETE".equalsIgnoreCase(req.getMethod())) {
			doDelete(req, resp);
			return;
		}
		if ("PROPPATCH".equalsIgnoreCase(req.getMethod())) {
			return;
		}
		if ("GET".equalsIgnoreCase(req.getMethod())) {
			doGet(req, resp);
			return;
		}
		ServletInputStream is = req.getInputStream();
		ByteArrayOutputStream os = new ByteArrayOutputStream();
		flushStream(is, os);
		super.service(req, resp);
	}
    
    void flushStream(InputStream is, OutputStream os) throws IOException {
		int len;
		byte[] buf = new byte[1024];
		while ((len = is.read(buf)) != -1) {
			os.write(buf, 0, len);
		}
		os.close();
    }
    
    /**
     * authenticate whether user and password exists in accounts
     * @param user
     * @param pass
     * @return
     */
    private boolean authenticate(String user, String pass) {
    	return accounts.contains(user + ":" + pass);
	}

	/**
     * build file path from request
     * (e.g.) requesturl: http://server/simple_webdav_servlet/SimpleWebDAVServlet/path/to/file ,basepath: C:\share\
     * -> filepath: C:\share\path\to\file
     */
    private String getFilePath(HttpServletRequest req) {
    	String requestURI = req.getRequestURI();
    	requestURI = URLDecoder.decode(requestURI, Charset.availableCharsets().get("UTF-8"));
    	String davbasepath = req.getContextPath()+req.getHttpServletMapping().getPattern();
    	davbasepath = davbasepath.replace("*", "");
    	String subpath = "";
    	if (requestURI.length() >= davbasepath.length()) {
    		subpath = requestURI.substring(davbasepath.length());
    	}
    	// sanitizing
		subpath = subpath.replace(":", "").replace("$", "");
    	// change path separator for UNC path
		if (BASE_PATH.endsWith("/")) {
			if (subpath.startsWith("/")) {
				subpath = subpath.substring("/".length());
			}
		} else {
			if (subpath.startsWith("/") == false) {
				subpath = "/" + subpath;
			}
		}
		String filepath = BASE_PATH + subpath;
    	filepath = filepath.replace("/", File.separator);
    	return filepath;
    }
    
    private String getDAVPath(HttpServletRequest req) {
    	String requestURI = req.getRequestURI();
    	requestURI = URLDecoder.decode(requestURI, Charset.availableCharsets().get("UTF-8"));
    	String davbasepath = req.getContextPath()+req.getHttpServletMapping().getPattern();
    	davbasepath = davbasepath.replace("*", "");
    	String subpath = "";
    	if (requestURI.length() >= davbasepath.length()) {
    		subpath = requestURI.substring(davbasepath.length());
    	}
		if (subpath.startsWith("/") == false) {
			subpath = "/" + subpath;
		}
    	// sanitizing
		subpath = subpath.replace(":", "").replace("$", "");
    	return subpath;
    }
    
	/**
	 * Just the opposite process of getFilePath that converts filepath to URL
	 * @param req
	 * @param entry
	 * @param isDirectory 
	 * @return
	 */
	private String buildHref(HttpServletRequest req, Path entry, boolean isDirectory) {
		String absolutePath = entry.toFile().getAbsolutePath();
    	String davbasepath = req.getContextPath()+req.getHttpServletMapping().getPattern();
    	davbasepath = davbasepath.replace("*", "");
    	String subpath = "";
    	if (absolutePath.length() >= BASE_PATH.length()) {
    		subpath = absolutePath.substring(BASE_PATH.length());
    	}
		subpath = subpath.replace(File.separator, "/");
		if (isDirectory && (subpath.endsWith("/") == false)) {
			subpath = subpath + "/";
		}
		if (subpath.startsWith("/")) {
			subpath = subpath.substring("/".length());
		}
		return davbasepath + subpath;
	}
	
	/**
	 * Just the opposite process of getFilePath that converts filepath to URL
	 * @param req
	 * @param davpath
	 * @param isDirectory 
	 * @return
	 */
	private String buildHrefFromDAVPath(HttpServletRequest req, String davpath, boolean isDirectory) {
    	String davbasepath = req.getContextPath()+req.getHttpServletMapping().getPattern();
    	davbasepath = davbasepath.replace("*", "");
		if (isDirectory && (davpath.endsWith("/") == false)) {
			davpath = davpath + "/";
		}
		if (davpath.startsWith("/")) {
			davpath = davpath.substring("/".length());
		}
		return davbasepath + davpath;
	}

    @Override
	protected void doOptions(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
    	resp.addHeader("Allow", "OPTIONS, GET, HEAD, PUT, DELETE, MKCOL");
    	resp.addHeader("DAV", "1, 2, ordered-collections");
	}
    
	@Override
    protected void doDelete(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
		String path = getFilePath(req);
		File file = new File(path);
		boolean success = file.delete();
		if (success) {
			resp.setStatus(204);
		} else {
			resp.sendError(500);
		}
    }
    
    @Override
    protected void doPut(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
		String path = getFilePath(req);
		File file = new File(path);
		boolean success = true;
		try {
			file.createNewFile();
			FileOutputStream os = new FileOutputStream(file, false);
			InputStream is = req.getInputStream();
			flushStream(is, os);
		} catch (IOException e) {
			success = false;
		}
		if (success) {
			resp.setStatus(201);
		} else {
			resp.sendError(500);
		}
    }
    
    private void doMkcol(HttpServletRequest req, HttpServletResponse resp) throws IOException {
    	String path = getFilePath(req);
		if (path.endsWith("/") == false) {
			path = path + "/";
		}
		File file = new File(path);
		boolean success = file.mkdirs();
		if (success) {
			resp.setStatus(201);
		} else {
			resp.sendError(500);
		}
	}

	protected void doPropfind(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		String path = getFilePath(request);
		if (path.endsWith("/") == false) {
			path = path + "/";
		}
		File file = new File(path);
		if (file.exists() == false) {
			response.sendError(404);
			return;
		}
		
		response.setStatus(207);
		response.setContentType("text/xml");
		response.setCharacterEncoding("UTF-8");
		PrintWriter writer = response.getWriter();
		writer.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<multistatus xmlns=\"DAV:\">");
		
		SimpleDateFormat dateFormat = new SimpleDateFormat("EEE, dd MMM yyyy hh:mm:ss", Locale.ENGLISH);

		try (DirectoryStream<Path> stream = Files.newDirectoryStream(file.toPath())) {
			for (Path entry: stream) {
				BasicFileAttributes attrs = Files.readAttributes(entry, BasicFileAttributes.class);
				String href = buildHref(request, entry, attrs.isDirectory());
				if (attrs.isDirectory()) {
					writer.append("<response>\r\n" + 
							"<href>"+href+"</href>\r\n" + 
							"<propstat>\r\n" + 
							"<prop>\r\n" + 
							"<creationdate>"+dateFormat.format(new Date(attrs.creationTime().toMillis()))+" GMT+09:00</creationdate>\r\n" + 
							"<getlastmodified>"+dateFormat.format(new Date(attrs.lastModifiedTime().toMillis()))+" GMT+09:00</getlastmodified>\r\n" + 
							"<resourcetype><collection/></resourcetype>\r\n" + 
							"</prop>\r\n" + 
							"<status>HTTP/1.1 200 OK</status>\r\n" + 
							"</propstat>\r\n" + 
							"</response>");
				} else {
					writer.append("<response>\r\n" + 
							"<href>"+href+"</href>\r\n" + 
							"<propstat>\r\n" + 
							"<prop>\r\n" + 
							"<displayname>"+entry.getFileName().toString()+"</displayname>\r\n" + 
							"<creationdate>"+dateFormat.format(new Date(attrs.creationTime().toMillis()))+" GMT+09:00</creationdate>\r\n" + 
							"<getlastmodified>"+dateFormat.format(new Date(attrs.creationTime().toMillis()))+"</getlastmodified>\r\n" + 
							"<getcontentlength>"+attrs.size()+"</getcontentlength>\r\n" + 
							"</prop>\r\n" + 
							"<status>HTTP/1.1 200 OK</status>\r\n" + 
							"</propstat>\r\n" + 
							"</response>");
				}
			}
		} catch (DirectoryIteratorException ex) {
			throw ex.getCause();
		}
		writer.append("</multistatus>");
    }
    
	/**
	 * @see HttpServlet#doGet(HttpServletRequest request, HttpServletResponse response)
	 */
	protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
		String path = getFilePath(request);
		String davPath = getDAVPath(request);
		File file = new File(path);
		if (davPath.endsWith("/")) {
			if (file.exists() == false) {
				response.sendError(404);
				return;
			}
			response.setContentType("text/html");
			response.setCharacterEncoding("UTF-8");
			PrintWriter writer = response.getWriter();
			writer.append("<html><head><title>Index of "+davPath+"</title><style type=\"text/css\">" +
					"a {\r\n" + 
					"	font-size: large;\r\n" + 
					"}\r\n" + 
					"a.titlesegment {\r\n" + 
					"	font-size: x-large;\r\n" + 
					"	text-decoration: none;\r\n" + 
					"}\r\n" + 
					"h1 {\r\n" + 
					"	background-color: #fffacd;\r\n" + 
					"	-moz-border-radius: 5px; /* ??????Firefox */\r\n" + 
					"	-webkit-border-radius: 5px; /* ??????Safari,Chrome */\r\n" + 
					"	border-radius: 5px; /* CSS3 */\r\n" + 
					"	padding-top: 10px;\r\n" + 
					"	padding-bottom: 10px;\r\n" + 
					"	text-align: center;\r\n" + 
					"	border: 1px solid #f5deb3;\r\n" + 
					"	font-size: x-large;\r\n" + 
					"	color: brown;\r\n" + 
					"}\r\n" + 
					"span {\r\n" + 
					"	background-color: #ffffff;\r\n" + 
					"	-moz-border-radius: 30px; /* ??????Firefox */\r\n" + 
					"	-webkit-border-radius: 30px; /* ??????Safari,Chrome */\r\n" + 
					"	border-radius: 30px; /* CSS3 */\r\n" + 
					"	border: 1px solid gray;\r\n" + 
					"	padding-left: 15px;\r\n" + 
					"	padding-right: 15px;\r\n" + 
					"	color: black;\r\n" + 
					"}\r\n" + 
					"hr {\r\n" + 
					"	display: none;\r\n" + 
					"}\r\n" + 
					"pre{\r\n" + 
					"     line-height: 150%;\r\n" + 
					"     padding-left: 5px;\r\n" + 
					"}</style></head><body>");
			writer.append("<h1>Index of: <span>");
			String[] segments = davPath.split("/", -1);
			writer.append("/");
			String davpath = "/";
			for (String segment : segments) {
				if (segment.trim().length() == 0) {
					continue;
				}
				writer.append("<a class=\"titlesegment\" href=\"");
				davpath = davpath + segment + "/";
				String subhref = buildHrefFromDAVPath(request, davpath, true);
				writer.append(subhref);
				writer.append("\">");
				writer.append(segment);
				writer.append("</a>");
				writer.append("/");
			}
			writer.append("</span></h1><hr><pre>");
			
			// show parent directory unless this is document root
			if (file.equals(new File(BASE_PATH)) == false) {
				String parenthref = buildHref(request, file.getParentFile().toPath(), true);
				writer.append("<a href=\""+parenthref+"\">../</a>\n");
			}

			SimpleDateFormat dateFormat = new SimpleDateFormat("dd-MMM-yyyy hh:mm", Locale.ENGLISH);
			try (DirectoryStream<Path> stream = Files.newDirectoryStream(file.toPath())) {
				for (Path entry: stream) {
					BasicFileAttributes attrs = Files.readAttributes(entry, BasicFileAttributes.class);
					String href = buildHref(request, entry, attrs.isDirectory());
					if (attrs.isDirectory()) {
						writer.append("<a href=\""+ href + "\">" + entry.toFile().getName() + "/</a>                       \n");
					} else {
						writer.append("<a href=\""+ href + "\">"+ entry.toFile().getName() +"</a>        " + dateFormat.format(new Date(attrs.lastModifiedTime().toMillis())) + "  " + attrs.size() + "   -\n");
					}
				}
			} catch (DirectoryIteratorException ex) {
				throw ex.getCause();
			}
			writer.append("</pre><hr></body></html>");
			return;
		} else {
			if (file.exists()) {
				FileInputStream is = new FileInputStream(file);
				OutputStream os = response.getOutputStream();
				flushStream(is, os);
				return;
			} else {
				response.sendError(404);
			}
		}
	}

}
SimpleWebDAVServlet servlet = new SimpleWebDAVServlet();
servlet.service(request, response);
 %>
