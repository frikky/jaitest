#import "Basic";
#import "File";
#import "String";
#import "Socket";
//#import "Http";

// Import from a module
// module :: #import, file "themodule/module.jai";

testloops :: () {
	filename := "Hello";
	//print("Filename to open: %\n", filename);
	filenames : [4]string = string.["heloo", "what", "ha", "ho"];

	// Normal array
	for i:0..filenames.count-1 {
		//print("Filename: %\n", filenames[i]);
	}

	// Objects: it, it_index
	for filenames {
		if it_index == 3 {
			break;
		}

		//print("Filename: %\n", it);
		//print("Filename: %\n", filenames[it_index]);

	}
}

readfile :: (filename: string) -> string {
	print("Filename to open: %\n", filename);
	text, TF := read_entire_file(filename);
	if TF {
	  print("Successfully read data from % of % length\n", filename, text.count);
	}  else {
	  print("Failed to read data from %\n", filename);
	}

	return "filedata";
}

write :: inline (fd: s32, msg: string) -> s64 {
    return send(fd, cast(*void) msg.data, xx msg.count, 0);
}

sendHttpRequest :: (url: string) { 
	// :string = dynamic
	// : *u8 = static?

	hostname := url;
	if begins_with(url, "http") && contains(url, "://") {
		hostname = replace(url, "http://", "");
	}

	if contains(hostname, "/") {
		hostname = split(hostname, "/")[0];
	}

	print("New url: %\n", hostname);

	print("In http request handler for url: %\n", url);

	// Create socket
	// What is the "." before SOCK_STREAM?
	sockfd := socket(AF_INET, .SOCK_STREAM, 0);
	if sockfd < 0 {
		print("Error opening socket\n");
		return;
	}


	foundip := gethostbyname(to_c_string(hostname));
	if foundip.h_length == 0 {
		print("Error getting ip\n");
		return;
	}

	// IPv6 garbage  with underscores?
	//print("Found ip % for domain '%'\n", foundip.h_addr_list, hostname);
	//print("Found ip % for domain '%'\n", foundip.h_addr_list, hostname);

	// What is SOL and REUSEADDR?
	// Sets socket options in the background. No variable change
	// needed directly, as this changes the struct in the background.
	optval := 1;
	if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, *optval, 4) < 0 {
		print("Error setting socket options\n");
		return;
	}

	startIP := "0.0.0.0";
	foundIP := "216.239.32.21";
	selectedPort := "80";

	bindRet := bind(sockfd, startIP, 30000);
	if bindRet < 0 {
		err := get_last_socket_error();
		print("Error binding socket to % (%): %\n", startIP, bindRet, err);
		return;
	}


	// Connect to socket

	print("Successfully bound socket to %. Now connecting to IP % on port %\n", startIP, foundIP, selectedPort);

	// What is htons?
	//connect :: (s: SOCKET, name: *sockaddr, namelen: s32) -> s32 #foreign ws2_32;

	// https://github.com/rluba/twitch_irc/blob/master/module.jai
	hints : addrinfo;
	hints.ai_family = AF_INET;
	hints.ai_socktype = .SOCK_STREAM;
	hints.ai_protocol = .TCP;

	c_hostname := temp_c_string(hostname);
    c_port := temp_c_string(selectedPort);

	info: *addrinfo;
    result := getaddrinfo(c_hostname, c_port, *hints, *info);
    if result {
		err := get_last_socket_error();
		print("Error connecting to %: %\n", foundIP, err);
		return;
	}
    defer freeaddrinfo(info);


	/*
	ipsize := 14;
	newIP : [ipsize]u8;
	destConfig : sockaddr; 
	for i:0..foundIP.count-1 {
		newIP[i] = foundIP[i];
	}
    destConfig.sa_family = AF_INET;
    destConfig.sa_data = newIP;
	*/


	configLength : socklen_t = 14;
	//connectRet := connect(sockfd, *destConfig, foundIP.count);
	connectRet := connect(sockfd, info.ai_addr, info.ai_addrlen);
	if connectRet < 0 {
		err := get_last_socket_error();
		print("Error connecting to % (%): %\n", foundIP, connectRet, err);
		return;
	}

	print("Successfully connected to %\n", foundIP);

	data := "GET / HTTP/1.1\r\nHost: %\r\n\r\n";
	resp := write(sockfd, data);
	//resp := send(sockfd, cast(*void) data, xx data.count, 0);
	if resp < 0 {
		err := get_last_socket_error();

		print("Error sending data (%): %\n", resp, err);
		return;
	}

	print("Successfully sent data to %\n", foundIP);

	// Read response
	response : [1024]u8;
	recvd := recv(sockfd, *response, 1024, 0);
	if recvd < 0 {
		err := get_last_socket_error();
		print("Error receiving data (%): %\n", recvd, err);
		return;
	}

	if recvd == 0 {
		print("No data received\n");
		return;
	}

	print("Successfully received data from %: %\n", foundIP, response);
	for i:0..recvd-1 {
		print("%", atoi(response[i]));
	}

}

openWindow :: () {
	print("In open windows window\n");
}

main :: () {
	print("\n\n\nHello world\n");

	testloops();

	filenames : [1]string = string.["test.jai"];
	for filenames {
		filedata := readfile(it);

		// 1. Modify filename to have .bak
		// 2. Write filedata to <filename>.bak

		filename := join(it, ".bak");
		valid := write_entire_file(filename, filedata);
		if valid {
			print("Successfully wrote data to %\n", filename);
		} else {
			print("Failed to write data to %\n", filename);
		}
	}

	sendHttpRequest("http://shuffler.io/api/v1/getinfo");
	
	openWindow();
}
