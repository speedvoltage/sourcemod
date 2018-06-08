#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define BLUE	"{azure}"
#define RED	"{crimson}"
#define GREEN	"{green}"

public Plugin myinfo =
{
	name = "Client Connect Messages",
	author = "Peter Brev",
	description = "Client Connect Messages",
	version = "2.0",
	url = "https://peterbrev.info"
};

public void OnClientConnected(client)
{
	char name[MAX_NAME_LENGTH];
	char steamid[32];
	
	GetClientName(client, name, sizeof(name));

	if(StrEqual(steamid, "STEAM_0:1:200137610", true))
	{
		CPrintToChatAll("%s[Owner %s%s %s%s %sis now connected.]", GREEN, RED, name, GREEN, steamid, GREEN);
		return;
	} else {
		CPrintToChatAll("%s[Player %s%s %s%s %sis now connected.]", BLUE, RED, name, GREEN, steamid, BLUE);
		return;
	}
}

public void OnClientDisconnect(client)
{
	char name[MAX_NAME_LENGTH];
	char steamid[32];
	GetClientName(client, name, sizeof(name));
	

	if(StrEqual(steamid, "STEAM_0:1:200137610", true))
	{
		CPrintToChatAll("%s[Owner %s%s %shas disconnected.]", GREEN, RED, name, GREEN);
		return;
	} else {
		CPrintToChatAll("%[sPlayer %s%s %shas disconnected.]", BLUE, RED, name, BLUE);
		return;
	}
}

