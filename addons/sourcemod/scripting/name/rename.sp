/** =============================================================================
 * Change Your Name - Functionality related to renaming
 * Rename a player and apply a cooldown.
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

public Action Command_Rename(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rename <#userid|name> <new name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1)/*Since we do not need players to use @all or similar, we are limiting it to one player at a time*/
	{
		return Plugin_Handled;
	}
	
	GetClientName(Target, currentname, sizeof(currentname));
	
	if (CheckCommandAccess(Target, "sm_admin", ADMFLAG_GENERIC))
	{
		ReplyToCommand(client, "[SM] You cannot target an admin.");
		return Plugin_Handled;
	}
	
	if (g_bForcedName[Target])
	{
		ReplyToCommand(client, "[SM] %N was recently forced renamed. Remove the forced locked name first to rename this player.", Target);
		return Plugin_Handled;
	}
	
	if (g_bAdminRenamed[Target]) delete g_hTimer[Target]; /*We do not want multiple timers on the same target*/
	
	char filebuffer[MAX_NAME_LENGTH];
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (hBadNames.GetString(i, filebuffer, sizeof(filebuffer)) && StrContains(arg2, filebuffer, false) != -1)
		{
			ReplyToCommand(client, "[SM] %s is banned from being used.", arg2);
			return Plugin_Handled;
		}
	}
	
	if (strcmp(currentname, arg2) == 0)
	{
		ReplyToCommand(client, "[SM] %s is already their name.", arg2);
		return Plugin_Handled;
	}
	
	Format(g_targetnewname[Target], MAX_NAME_LENGTH, "%s", arg2);
	ShowActivity2(client, "[SM] ", "Renamed %N.", Target);
	LogAction(client, Target, "%L renamed %L to %s.", client, Target, arg2);
	RenamePlayer(Target);
	g_bAdminRenamed[Target] = true;
	g_iRenameTracker++;
	g_iWasRenamed[Target]++;
	return Plugin_Handled;
}

void RenamePlayer(int target)
{
	SetClientName(target, g_targetnewname[target]);
	g_targetnewname[target][0] = '\0';
	
	int timeleft = GetConVarInt(changename_adminrename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToChat(target, "[SM] An admin renamed you. You have been temporarily banned from changing names for %d:%02d.", mins, secs);
	}
	
	Handle DP = CreateDataPack();
	WritePackCell(DP, GetClientUserId(target));
	g_hTimer[target] = CreateTimer(GetConVarFloat(changename_adminrename_cooldown), name_temp_ban, DP);
	
	return;
}

public Action name_temp_ban(Handle timer, any DP)
{
	ResetPack(DP);
	
	int target = GetClientOfUserId(ReadPackCell(DP));
	
	CloseHandle(DP);
	
	if (!target)
	{
		return Plugin_Stop;
	}
	
	g_bAdminRenamed[target] = false;
	PrintToChat(target, "[SM] Cooldown is over. You may now change your name again.");
	g_hTimer[target] = null;
	return Plugin_Stop;
} 