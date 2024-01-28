#import "Basic";
#import "File";
#import "String";
#import "Socket";
#import "SDL";
#if OS == .MACOS {
    #import "macos";
}
// Import from a module
#import, file "ascii.jai";

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

close_and_reset :: (sockfd: s32) {
	//close(sockfd);
	sockfd = -1;
}

handleEncryption :: (sockfd: s32, info: *addrinfo) -> bool {
	// Check if encryption is needed

	// If so, encrypt the socket
	return true;
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
	urlpath := "/";
	if begins_with(url, "https") && contains(url, "://") {
		hostname = replace(url, "https://", "");
	} else if begins_with(url, "http") && contains(url, "://") {
		hostname = replace(url, "http://", "");
	} else if contains(url, "://") {
		hostname = replace(url, "://", "");
	}

	if contains(hostname, "/") {
		hostnameSplit := split(hostname, "/");
		hostname = hostnameSplit[0];

		urlpath = "";
		for i:1..hostnameSplit.count-1 {
			if contains(hostnameSplit[i], "?") {
				hostnameSplit[i] = split(hostnameSplit[i], "?")[0];
				break;
			} else if contains(hostnameSplit[i], "#") {
				hostnameSplit[i] = split(hostnameSplit[i], "#")[0];
				break;
			} else {
				urlpath = join(urlpath, "/", hostnameSplit[i]);
			}
		}

	}

	print("In http request handler for url: %. Hostname: %\n", url, hostname);

	// Create socket
	// What is the "." before SOCK_STREAM?
	sockfd := socket(AF_INET, .SOCK_STREAM, 0);
	if sockfd < 0 {
		print("Error opening socket\n");
		return;
	}

	print("Successfully opened socket %\n", sockfd);

	// What is SOL and REUSEADDR?
	// Sets socket options in the background. No variable change
	// needed directly, as this changes the struct in the background.
	optval := 1;
	if setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, *optval, 4) < 0 {
		print("Error setting socket options\n");
		close_and_reset(sockfd);
		return;
	}

	startIP := "0.0.0.0";
	//foundIP := "216.239.32.21";

	// Just a few protocols
	selectedPort := "80";
	if contains(url, "ftp:") {
		selectedPort = "21";
	} else if contains(url, "https:") {
		selectedPort = "443";
	}

	bindRet := bind(sockfd, startIP, 30000);
	if bindRet < 0 {
		err := get_last_socket_error();
		print("Error binding socket to % (%): %\n", startIP, bindRet, err);
		close_and_reset(sockfd);
		return;
	}


	// Connect to socket
	//print("Successfully bound socket to %. Now connecting to IP % on port %\n", startIP, foundIP, selectedPort);
	print("Successfully bound socket to %. Now connecting on port %\n", startIP, selectedPort);

	// What is htons?

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
		print("Error connecting to %: %\n", hostname, err);
		close_and_reset(sockfd);
		return;
	}

    defer freeaddrinfo(info);

	configLength : socklen_t = 14;
	connectRet := connect(sockfd, info.ai_addr, info.ai_addrlen);
	if connectRet < 0 {
		err := get_last_socket_error();
		print("Error connecting % (%): %n", hostname, connectRet, err);

		close_and_reset(sockfd);
		return;
	}

	print("Successfully connected to %\n", hostname);


	encryptionFailed := handleEncryption(sockfd, info);
	if encryptionFailed {
		close_and_reset(sockfd);
		return;
	}


	data := sprint("GET % HTTP/1.1\nHost: %\n\n", urlpath, hostname);
	print("Sending data: \n%\n", data);

	resp := write(sockfd, data);
	if resp < 0 {
		err := get_last_socket_error();
		print("Error sending data (%): %\n", resp, err);

		close_and_reset(sockfd);
		return;
	}

	print("Successfully sent data to %\n", hostname);

	// Read response
	response : [4096]u8;
	recvd := recv(sockfd, *response, 1024, 0);
	if recvd < 0 {
		err := get_last_socket_error();
		print("Error receiving data (%): %\n", recvd, err);
		close_and_reset(sockfd);
		return;
	}

	if recvd == 0 {
		print("No data received\n");
		close_and_reset(sockfd);
		return;
	}

	print("Successfully received data from %\n\n", hostname);

	fullString := "";
	for i:0..recvd-1 {
		resp := get_letter(response[i]);
		fullString = join(fullString, resp);
	}

	httpVersion := "";
	statusCode := -1;
	splitString := split(fullString, "\n");
	for splitString {
		if contains(it, "HTTP/") {
			stringSplit := split(it, " ");
			httpVersion = stringSplit[0];
			statusCode = string_to_int(stringSplit[1]);
		}
	}

	print("%\nStatus: %\n", fullString, statusCode);
}

cell_size    : u16 : 66;
between_box  : u16 : 1;
padding      : u16 : 20;

full_size    : u16 : cell_size*9 + between_box*2 + padding*2 + 1;
openWindow :: () {
	print("In open windows window\n");

	SDL_Init(SDL_INIT_VIDEO);

    window := SDL_CreateWindow(
		"Jaidoku",
        SDL_WINDOWPOS_CENTERED, 
		SDL_WINDOWPOS_CENTERED,
        full_size, full_size,
        SDL_WINDOW_OPENGL
	);

	if window == null {
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }

    renderer := SDL_CreateRenderer(window, -1, 0);


}

main :: () {
	print("\n\n\nHello world\n");

	/*
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
	*/

	//sendHttpRequest("http://shuffler.io/api/v1/getinfo");
	//sendHttpRequest("https://shuffler.io/api/v1/getinfo");
	
	print("\n\nStart");
	openWindow();
}
