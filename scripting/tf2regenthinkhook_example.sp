
#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2regenthinkhook>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "22w44a"

public Plugin myinfo = {
	name = "[TF2] Regen Think Hooks - Example Plugin",
	author = "reBane",
	description = "Cycle no regen, all class regen and give permanent ammo/metal regen",
	version = PLUGIN_VERSION,
	url = "https://github.com/DosMike/TF2-RegenThinkHook"
}

bool mode2;

public void OnPluginStart() {
	CreateTimer(10.0, Timer_SwitchMode, _, TIMER_REPEAT);
}

public Action Timer_SwitchMode(Handle timer) {
	mode2 =! mode2;
	
	if (mode2) {
		PrintToChatAll("[Example Plugin] Class based health regen for all players");
	} else {
		PrintToChatAll("[Example Plugin] No class based health regen");
	}
}

public Action TF2_OnClientRegenThinkHealth(int client, float& regenClass, float& regenAttribs) {
	if (mode2) {
		regenClass = 3.0;
	} else {
		regenClass = 0.0;
	}
	return Plugin_Changed;
}

public Action TF2_OnClientRegenThinkAmmo(int client, float& regenAmmo, int& regenMetal) {
	regenAmmo = 0.1;
	if (TF2_GetPlayerClass(client) == TFClass_Engineer)
		regenMetal = 10;
}

public void TF2_OnClientRegenThinkPost(int client, int regenHealth, float regenAmmo, int regenMetal) {
	PrintToChat(client, "[Example Plugin] You regenerated %i HP, %.2f%% Ammo and %i Metal", regenHealth, regenAmmo*100.0, regenMetal);
}