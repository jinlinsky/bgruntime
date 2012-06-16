#include "Socket.h"

#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <netdb.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <netinet/in.h>
#include <arpa/inet.h>

Socket Socket::gSharedSocket;

int gSocketFD = -1;

int 	Socket::Connect( const char* ip, int port )
{
	gSocketFD = socket(AF_INET, SOCK_STREAM, 0);

	//unsigned long nonblock = 1;
	//ioctl(gSocketFD, FIONBIO, &nonblock);

	struct hostent* hp = gethostbyname(ip);

	struct sockaddr_in	pin;
	memset(&pin, 0, sizeof(pin));
	pin.sin_family		= AF_INET;
	pin.sin_addr.s_addr = ((struct in_addr *)(hp->h_addr))->s_addr;
	pin.sin_port        = htons(port);

	int result = connect(gSocketFD,(struct sockaddr *)  &pin, sizeof(pin)); 

	return result;
}

void	Socket::Disconnect( void )
{
	close(gSocketFD);
}

void	Socket::Recv( char* buffer, int bufferSize )
{
	struct timeval timeOut;
	timeOut.tv_sec = 0;
	timeOut.tv_usec= 0;

	fd_set fdR;
	FD_ZERO(&fdR);
	FD_SET(gSocketFD, &fdR);

	if (select(gSocketFD + 1, &fdR, NULL, NULL, &timeOut) != -1)
	{
		if (FD_ISSET(gSocketFD, &fdR))
		{
			recv(gSocketFD, buffer, bufferSize, 0);
			printf("%s\n", buffer);
		}        
	}
}

void	Socket::Send( const char* buffer, int bufferSize )
{
	struct timeval timeOut;
	timeOut.tv_sec = 0;
	timeOut.tv_usec= 0;

	fd_set fdW;
	FD_ZERO(&fdW);
	FD_SET(gSocketFD, &fdW);

	// if socket is connected, then it should can be write and read both.
	if (select(gSocketFD + 1, NULL, &fdW, NULL, &timeOut) != -1)
	{
		if (FD_ISSET(gSocketFD, &fdW))
		{
		    send(gSocketFD, buffer, bufferSize, 0);
		}
	}
}