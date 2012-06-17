#ifndef _SOCKET_H_
#define _SOCKET_H_

class Socket
{
public:

	enum ConnectState
	{
		CS_NOT_CONNECTED = 0,
		CS_CONNECTING,
		CS_CONNECTED
	};

	Socket()
	{
		mState = CS_NOT_CONNECTED;
		gSocketFD = socket(AF_INET, SOCK_STREAM, 0);
	}

	int     Connect         ( const char* ip, int port, bool nonblock );
	void	Disconnect      ( void );
	void    Recv            ( char* buffer, int bufferSize );
	void	Send            ( const char* buffer, int bufferSize );
	int     GetConnectState ( void );

	static  Socket gSharedSocket;

private:
	bool	IsConnected     ( void );
	
	int     mState;
};

#endif //_SOCKET_H_