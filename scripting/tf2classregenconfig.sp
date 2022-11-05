#include <sourcemod>
#include <tf2>
#include <tf2_stocks>
#include <tf2regenthinkhook>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "22w44c"

public Plugin myinfo = {
	name = "[TF2] Class Regeneration Configuration",
	author = "reBane",
	description = "Control health, ammo and metal regenration for everyone",
	version = PLUGIN_VERSION,
	url = "https://github.com/DosMike/TF2-RegenThinkHook"
}

enum struct RegenParams {
	bool active; //wether this instance was set
	float baseRegen;
	float healingAdd; //for medics only, add regen if having a patient by this value
	float noDamageStart; //time in seconds after last damage that starts scaling healing
	float noDamageEnd; //time in seconds after last damage that does not longer scale healing
	//if noDamageAdd is true, will add a value from 0..noDamageScale on top of baseRegen and healingAdd over the timespan
	//otherwise it will compute as multiplye instead:
	//at noDamageStart the multiplier is still 1, at noDamageEnd it will be scaled to noDamageScale
	float noDamageScale;
	bool noDamageAdd;
	bool neverHurt; //if the adjusted combined heal value turns out to be less than zero, don't damage at all
	float ammoScale; //scale the value provided by attributes
	float ammoAdd; //fixed addition of ammo every 5s
	float metalScale; //scale the value provided by attributes
	int metalAdd; //fixed addition of metal every 5s
}
RegenParams __defaultParams = { false, 0.0, 0.0, 5.0, 10.0, 2.0, false, false, 1.0, 0.0, 1.0, 0 };
RegenParams ClassOverrides[10];
RegenParams PlayerOverrides[33];

// config keys, allow user defined "defaults" for all-class
char tf2classnames[10][12] = { "#default", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer" };

int g_lastDamageOffset;

GlobalForward fwd_ConfigReloaded;

public void OnPluginStart() {
	GameData data = new GameData("tf2rth.games");
	g_lastDamageOffset = data.GetOffset("CTFPlayer::m_flLastDamageTime");
	delete data;
	if (g_lastDamageOffset == -1) SetFailState("Could not load offsets from tf2rth.games.txt");
	
	fwd_ConfigReloaded = CreateGlobalForward("TF2RegenConfig_OnConfigLoaded", ET_Ignore);
	
	RegAdminCmd("sm_classregen_reloadconfig", ConCmd_ReloadConfig, ADMFLAG_CONFIG, "Reload the config from disk");
	
	ConVar version = CreateConVar("sm_tf2classregenconfig_version", PLUGIN_VERSION, "Version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	version.SetString(PLUGIN_VERSION);
	version.AddChangeHook(OnVersionChanged);
	delete version;
}
public void OnVersionChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (!StrEqual(newValue,PLUGIN_VERSION)) {
		convar.SetString(PLUGIN_VERSION);
	}
}

public void OnAllPluginsLoaded() {
	if (!LibraryExists("tf2regenthinkhook"))
		SetFailState("TF2 RegenThink Hook was not found");
}

public Action ConCmd_ReloadConfig(int client, int args) {
	LoadConfig(client);
	ReplyToCommand(client, "[TF2 ClassRegenConfig] Reloaded");
	return Plugin_Handled;
}

public void OnConfigsExecuted() {
	LoadConfig(0);
}

public void LoadConfig(int replyTo) {
	KeyValues regenConfig = new KeyValues("ClassRegenConfig");
	if (!regenConfig.ImportFromFile("cfg/sourcemod/classregenconfig.cfg")) {
		if (replyTo) ReplyToCommand(replyTo, "[TF2 ClassRegenConfig] Failed to load config from cfg/sourcemod/classregenconfig.cfg");
		else PrintToServer("[TF2 ClassRegenConfig] Failed to load config from cfg/sourcemod/classregen.cfg");
		delete regenConfig;
		return;
	}
	
	for (TFClassType clz=TFClass_Unknown; clz <= TFClass_Engineer; clz++) {
		float defaultValue = (clz == TFClass_Medic)?3.0:0.0;
		if (regenConfig.JumpToKey(tf2classnames[clz])) {
			char tmp[64];
			regenConfig.GetString("copy", tmp, sizeof(tmp));
			if (tmp[0]!=0) {
				regenConfig.GoBack();
				if (!regenConfig.JumpToKey(tmp)) {
					if (replyTo) ReplyToCommand(replyTo, "[TF2 Class Regen] Failed to copy section \"%s\" into \"%s\", not found", tmp, tf2classnames[clz]);
					else PrintToServer("[TF2 ClassRegenConfig] Failed to copy section \"%s\" into \"%s\", not found", tmp, tf2classnames[clz]);
					continue;
				}
			}
			ClassOverrides[clz].active = true;
			ClassOverrides[clz].baseRegen = regenConfig.GetFloat("baseRegen",defaultValue);
			ClassOverrides[clz].healingAdd = regenConfig.GetFloat("healingAdds",defaultValue);
			if (regenConfig.JumpToKey("noDamageBoost")) {
				ClassOverrides[clz].noDamageStart = regenConfig.GetFloat("startAfterSec",__defaultParams.noDamageStart);
				ClassOverrides[clz].noDamageEnd = regenConfig.GetFloat("scaleUntilSec",__defaultParams.noDamageEnd);
				ClassOverrides[clz].noDamageScale = regenConfig.GetFloat("maxScale",__defaultParams.noDamageScale);
				ClassOverrides[clz].noDamageAdd = regenConfig.GetNum("additive",__defaultParams.noDamageAdd)>0;
				regenConfig.GoBack();
			} else {
				ClassOverrides[clz].noDamageStart = __defaultParams.noDamageStart;
				ClassOverrides[clz].noDamageEnd = __defaultParams.noDamageEnd;
				ClassOverrides[clz].noDamageScale = __defaultParams.noDamageScale;
				ClassOverrides[clz].noDamageAdd = __defaultParams.noDamageAdd;
			}
			ClassOverrides[clz].neverHurt = regenConfig.GetNum("neverHurt",__defaultParams.neverHurt)>0;
			if (regenConfig.JumpToKey("ammo")) {
				ClassOverrides[clz].ammoScale = regenConfig.GetFloat("scaleAttributeValue",__defaultParams.ammoScale);
				ClassOverrides[clz].ammoAdd = regenConfig.GetFloat("addRegenPrecent",__defaultParams.ammoAdd*100.0)/100.0;
				regenConfig.GoBack();
			} else {
				ClassOverrides[clz].ammoScale = __defaultParams.ammoScale;
				ClassOverrides[clz].ammoAdd = __defaultParams.ammoAdd;
			}
			if (regenConfig.JumpToKey("metal")) {
				ClassOverrides[clz].metalScale = regenConfig.GetFloat("scaleAttributeValue",__defaultParams.metalScale);
				ClassOverrides[clz].metalAdd = regenConfig.GetNum("addRegenAmount",__defaultParams.metalAdd);
				regenConfig.GoBack();
			} else {
				ClassOverrides[clz].metalScale = __defaultParams.metalScale;
				ClassOverrides[clz].metalAdd = __defaultParams.metalAdd;
			}
			regenConfig.GoBack();
		} else {
			ClassOverrides[clz] = __defaultParams;
			ClassOverrides[clz].baseRegen = defaultValue;
			ClassOverrides[clz].healingAdd = defaultValue;
		}
	}
	delete regenConfig;
	
	//reset client configs
	for (int i=0; i<33; i++) {
		PlayerOverrides[i].active = false;
	}
	
	Notify_ConfigLoaded();
}

public void OnClientDisconnect_Post(int client) {
	PlayerOverrides[client].active=false;
}

stock bool GetRegenParams(int client, RegenParams params) {
	TFClassType class = TF2_GetPlayerClass(client);
	if (PlayerOverrides[client].active) {
		CopyParams(ClassOverrides[client], params);
	} else if (class && ClassOverrides[class].active) {
		CopyParams(ClassOverrides[class], params);
	} else if (ClassOverrides[0].active) {
		CopyParams(ClassOverrides[0], params);
	} else { //defaults
		CopyParams(__defaultParams, params);
		params.baseRegen = params.healingAdd = (class == TFClass_Medic ? 3.0 : 0.0);
	}
	return params.active;
}

RegenParams g_clientParams;

public Action TF2_OnClientRegenThinkPre(int client) {
	GetRegenParams(client, g_clientParams);
	return Plugin_Continue;
}

public Action TF2_OnClientRegenThinkHealth(int client, float& regenClass, float& regenAttribs) {
	if (!g_clientParams.active) return Plugin_Continue;
	
	float regen = g_clientParams.baseRegen;
	
	float boost = g_clientParams.healingAdd;
	if (GetMedicPatient(client)>0) regen += boost;
	
	float timeSinceDamage = GetGameTime() - GetEntDataFloat(client, g_lastDamageOffset);
	if (timeSinceDamage >= g_clientParams.noDamageEnd) {
		if (g_clientParams.noDamageAdd)
			regen += g_clientParams.noDamageScale;
		else
			regen *= g_clientParams.noDamageScale;
	} else if (timeSinceDamage >= g_clientParams.noDamageStart && g_clientParams.noDamageEnd >= 0.0) {
		if (g_clientParams.noDamageStart == g_clientParams.noDamageEnd) {
			boost = g_clientParams.noDamageScale;
		} else if (g_clientParams.noDamageEnd > g_clientParams.noDamageStart) {
			timeSinceDamage -= g_clientParams.noDamageStart; //remove offset
			boost = timeSinceDamage / (g_clientParams.noDamageEnd-g_clientParams.noDamageStart); //normalize over timespan
			if (g_clientParams.noDamageAdd)
				boost *= g_clientParams.noDamageScale; //scale to output range 0 @ 0
			else
				boost *= (g_clientParams.noDamageScale-1.0); //scale to output range 1x @ 0
		} else boost = 0.0;
		if (g_clientParams.noDamageAdd)
			regen += boost;
		else
			regen *= boost+1.0; //re-add initial scale offset
	}
	regenClass = regen;
	
	if (g_clientParams.neverHurt && (regenClass + regenAttribs) < 0.0) {
		regenClass = regenAttribs = 0.0;
	}
	
	return Plugin_Changed;
}

public Action TF2_OnClientRegenThinkAmmo(int client, float& regenAmmo, int& regenMetal) {
	if (!g_clientParams.active) return Plugin_Continue;
	
	regenAmmo = regenAmmo * g_clientParams.ammoScale + g_clientParams.ammoAdd;
	regenMetal = RoundToNearest(regenMetal * g_clientParams.metalScale) + g_clientParams.metalAdd;
	
	return Plugin_Changed;
}

static int GetMedicPatient(int medic) {
	if (TF2_GetPlayerClass(medic) != TFClass_Medic) return -1;
	int weapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
	char clzname[64];
	if (weapon == INVALID_ENT_REFERENCE || !GetEdictClassname(weapon,clzname,sizeof(clzname)) || !StrEqual(clzname,"tf_weapon_medigun")) return -1;
	return GetEntPropEnt(weapon, Prop_Send, "m_hHealingTarget");
}

// natives & forwards

static void Notify_ConfigLoaded() {
	Call_StartForward(fwd_ConfigReloaded);
	Call_Finish();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("TF2RegenConfig_GetEffectiveOverride", Native_GetEffectiveOverride);
	CreateNative("TF2RegenConfig_GetPlayerOverride", Native_GetPlayerOverride);
	CreateNative("TF2RegenConfig_SetPlayerOverride", Native_SetPlayerOverride);
	CreateNative("TF2RegenConfig_GetClassOverride", Native_GetClassOverride);
	CreateNative("TF2RegenConfig_SetClassOverride", Native_SetClassOverride);
	RegPluginLibrary("tf2classregenconfig");
	return APLRes_Success;
}

public any Native_GetEffectiveOverride(Handle plugin, int numParams) {
	if (numParams != 2) ThrowNativeError(SP_ERROR_PARAM, "Missing parameter");
	int client = GetNativeCell(1);
	if (0<=client<=MaxClients && IsClientInGame(client)) {
		RegenParams params;
		bool result = GetRegenParams(client, params);
		int error;
		if ((error=SetNativeArray(2, params, sizeof(RegenParams)))!=SP_ERROR_NONE)
			ThrowNativeError(error, "Could not write regen override params");
		return result;
	} else {
		ThrowNativeError(SP_ERROR_PARAM, "Client not valid or not ingame");
	}
	return false;
}
public any Native_GetPlayerOverride(Handle plugin, int numParams) {
	if (numParams != 2) ThrowNativeError(SP_ERROR_PARAM, "Missing parameter");
	int client = GetNativeCell(1);
	if (0<=client<=MaxClients && IsClientInGame(client)) {
		RegenParams params;
		CopyParams(PlayerOverrides[client], params);
		//= PlayerOverrides[client];
		int error;
		if ((error=SetNativeArray(2, params, sizeof(RegenParams)))!=SP_ERROR_NONE)
			ThrowNativeError(error, "Could not write regen override params");
		return params.active;
	} else {
		ThrowNativeError(SP_ERROR_PARAM, "Client not valid or not ingame");
	}
	return false;
}
public any Native_SetPlayerOverride(Handle plugin, int numParams) {
	if (numParams != 2) ThrowNativeError(SP_ERROR_PARAM, "Missing parameter");
	int client = GetNativeCell(1);
	if (0<=client<=MaxClients && IsClientInGame(client)) {
		RegenParams params;
		int error;
		if ((error=GetNativeArray(2, params, sizeof(RegenParams))) != SP_ERROR_NONE)
			ThrowNativeError(error, "Could not read regen override params");
		CopyParams(params, PlayerOverrides[client]);
		//PlayerOverrides[client] = params;
	} else {
		ThrowNativeError(SP_ERROR_PARAM, "Client not valid or not ingame");
	}
	return 0;
}
public any Native_GetClassOverride(Handle plugin, int numParams) {
	if (numParams != 2) ThrowNativeError(SP_ERROR_PARAM, "Missing parameter");
	TFClassType class = GetNativeCell(1);
	if (TFClass_Unknown<=class<=TFClass_Engineer) {
		RegenParams params;
		CopyParams(ClassOverrides[class], params);
		//= ClassOverrides[class];
		int error;
		if ((error=SetNativeArray(2, params, sizeof(RegenParams)))!=SP_ERROR_NONE)
			ThrowNativeError(error, "Could not write regen override params");
		return params.active;
	} else {
		ThrowNativeError(SP_ERROR_PARAM, "Invalid player class index");
	}
	return false;
}
public any Native_SetClassOverride(Handle plugin, int numParams) {
	if (numParams != 2) ThrowNativeError(SP_ERROR_PARAM, "Missing parameter");
	TFClassType class = GetNativeCell(1);
	if (TFClass_Unknown<=class<=TFClass_Engineer) {
		RegenParams params;
		int error;
		if ((error=GetNativeArray(2, params, sizeof(RegenParams))) != SP_ERROR_NONE)
			ThrowNativeError(error, "Could not read regen override params");
		CopyParams(params, ClassOverrides[class]);
		//ClassOverrides[class] = params;
	} else {
		ThrowNativeError(SP_ERROR_PARAM, "Invalid player class index");
	}
	return 0;
}

static void CopyParams(const RegenParams from, RegenParams to) {
	to.active = from.active;
	to.baseRegen = from.baseRegen;
	to.healingAdd = from.healingAdd;
	to.noDamageStart = from.noDamageStart;
	to.noDamageEnd = from.noDamageEnd;
	to.noDamageScale = from.noDamageScale;
	to.noDamageAdd = from.noDamageAdd;
	to.neverHurt = from.neverHurt;
	to.ammoScale = from.ammoScale;
	to.ammoAdd = from.ammoAdd;
	to.metalScale = from.metalScale;
	to.metalAdd = from.metalAdd;
}