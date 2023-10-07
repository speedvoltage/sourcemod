/** =============================================================================
 * Change Your Name - Functionality related to refreshing banned_id.ini & banned_names.ini
 * Refreshes data in banned_id.ini & banned_names.ini
 *
 * Plugin developed by Peter Brev.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

public Action Command_Refresh(int client, int args)
{
	/*Banned names file*/
	
	hBadNames.Clear();
	
	Handle file = OpenFile(fileName, "a+");
	
	if (!file)
	{
		ReplyToCommand(client, "[SM] Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
		LogError("Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
		return Plugin_Handled;
	}
	
	char line[MAX_NAME_LENGTH], bannedline[MAX_NAME_LENGTH];
	while (!IsEndOfFile(file))
	{
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, sizeof(line), " ", "");
		
		if (!strlen(line) || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}

		hBadNames.PushString(line);
	}
	
	CloseHandle(file);
	
	ReplyToCommand(client, "[SM] Successfully reloaded banned_names.ini.");
	PrintToServer("[config/banned_names.ini] Loaded banned names: %i", hBadNames.Length);
	
	/*Banned Steam IDs file*/
	
	hBannedSteamId.Clear();
	
	Handle idfile = OpenFile(bannedidfile, "a+");
	
	if (!idfile)
	{
		ReplyToCommand(client, "[SM] Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
		LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
		return Plugin_Handled;
	}
	
	while (!IsEndOfFile(idfile))
	{
		if (!ReadFileLine(idfile, bannedline, sizeof(bannedline)))
		{
			break;
		}
		
		TrimString(bannedline);
		ReplaceString(bannedline, sizeof(bannedline), " ", "");
		
		if (!strlen(bannedline) || (bannedline[0] == '/' && bannedline[1] == '/'))
		{
			continue;
		}
		
		hBannedSteamId.PushString(bannedline);
	}
	
	CloseHandle(idfile);
	
	ReplyToCommand(client, "[SM] Successfully reloaded banned_id.ini.");
	PrintToServer("[config/banned_id.ini] Loaded banned Steam IDs: %i", hBannedSteamId.Length);
	LogMessage("%L has refreshed files.", client);
	
	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		char name[MAX_NAME_LENGTH];
		GetClientName(i, name, sizeof(name));
		NameCheck(name, i);
	}
	
	return Plugin_Handled;
} 