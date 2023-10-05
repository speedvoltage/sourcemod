/** =============================================================================
 * Change Your Name - Functionality related to banning/unbanning names
 * Add and remove names from banned_names.ini
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

public Action Command_NameBan(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_ban <name to ban>");
		return Plugin_Handled;
	}
	
	if (args > 1)
	{
		ReplyToCommand(client, "[SM] Only use one word with no spaces.");
		return Plugin_Handled;
	}
	
	char arg[64];
	GetCmdArgString(arg, sizeof(arg));
	Handle nfile = OpenFile(fileName, "a+");
	char linebuffer[256];
	while (ReadFileLine(nfile, linebuffer, sizeof(linebuffer)))ReplaceString(linebuffer, sizeof(linebuffer), "\n", "", false);
	
	WriteFileLine(nfile, arg);
	ReplyToCommand(client, "[SM] %s has been added to the banned names list.", arg);
	CloseHandle(nfile);
	
	LogMessage("%s has been added to banned_names.ini", arg);
	
	return Plugin_Handled;
}

public Action Command_NameUnban(int client, int args)
{
	File nfile = OpenFile(fileName, "a+");
	
	if (nfile == null)
	{
		ReplyToCommand(client, "[SM] Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
		LogError("Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_unban <name to unban (NO SPACES)>");
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while (!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0]))continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false);
		if (!StrEqual(arg1, arg2, false))
		{
			fileArray.PushString(arg1);
		}
		else
		{
			found = true;
		}
	}
	
	delete nfile;
	
	if (found)
	{
		DeleteFile(fileName);
		File newFile = OpenFile(fileName, "a+");
		
		if (newFile == null)
		{
			ReplyToCommand(client, "[SM] Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
			LogError("Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
			return Plugin_Handled;
		}
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
		}
		
		ReplyToCommand(client, "[SM] %s has been removed from the banned names list.", arg2);
		LogMessage("%s removed from banned names list by %L.", arg2, client);
		
		delete newFile;
		delete fileArray;
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[SM] The specified name could not be found.");
		return Plugin_Handled;
	}
}

