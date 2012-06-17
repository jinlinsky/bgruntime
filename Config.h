#ifndef __CONFIG_H__
#define __CONFIG_H__

#include <string>
#include <map>
#include "File.h"

class Config
{
public:
	Config( void ){};

    bool		LoadConfig	( const std::string& filename );
    std::string GetText		( const std::string& key );

protected:
	File		mFile;
	std::map<std::string, std::string>
				mConfigText;
};

#endif