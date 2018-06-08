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

public bool OnClientConnect(int client)
{
	CPrintToChatAll("%sPlayer %s%N %sis connecting...", BLUE, RED, client, BLUE);
	return true;
}

public void OnClientConnected(int client)
{
	char steamid[32];
	
	CPrintToChatAll("%sPlayer %s%N %s%s %sis now connected.", BLUE, RED, client, GREEN, steamid, BLUE);
	return;
}

public void OnClientDisconnect(int client)
{
	CPrintToChatAll("%sPlayer %s%N %shas disconnected.", BLUE, RED, client, BLUE);
	return;
}

