#include "File.h"

/*
constructor
*/
File::File( void )
: mFile(NULL)
{}

/*
destructor
*/
File::~File( void )
{
	Close();
}

/*
override read & write
*/
void	File::Read	( void* data, int size )
{
	fread (data, 1, size, mFile);
}

void	File::Write	( void* data, int size )
{
	fwrite(data, 1, size, mFile);
}

/*
method
*/
bool	File::Open	( const std::string& filename, int mode )
{
	Close();

	//combine open mode
	std::string openMode;
	if (mode & OM_READ  )	
		openMode += "r";
	if (mode & OM_WRITE )	
		openMode += "w";
	if (mode & OM_APPEND)	
		openMode += "a";
	if (mode & OM_BINARY)	
		openMode += "b";

	//open file and get file handle
	mFile = fopen(filename.c_str(), openMode.c_str());
	return mFile != NULL;
}

void	File::Seek	( int pos, SeekFlag flag )
{
	if (mFile)
	{
		switch (flag)
		{
		case SF_CUR:
			fseek(mFile, pos, SEEK_CUR);
			break;
		case SF_END:
			fseek(mFile, pos, SEEK_END);
			break;
		case SF_SET:
			fseek(mFile, pos, SEEK_SET);
			break;
		}
	}
}

void	File::Close	( void )
{
	if (mFile)
	{
		fclose(mFile);
		mFile = NULL;
	}
}