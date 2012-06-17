#include "Config.h"

bool	Config::LoadConfig( const std::string& filename )
{
	mConfigText.clear();

	if (mFile.Open(filename, File::OM_READ))
	{
		while (1)
		{
			std::string line;
			if (!mFile.ReadLine(line))
				break;

			int pos = line.find_first_of('=');
			if (pos != -1)
			{
				std::string key  = line.substr(0, pos);
				std::string text = line.substr(pos+1, line.length()-pos-1);
				mConfigText[key] = text;
			}
		}

		return true;
	}

	return false;
}

std::string	Config::GetText( const std::string& key )
{
	std::map<std::string, std::string>::iterator itor = mConfigText.find(key);
	if (itor != mConfigText.end())
		return (*itor).second;

	return "";
}