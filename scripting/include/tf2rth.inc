/**
 * The forwards in are called in the declared order. Interrupting the RegenThink
 * tick is only possible by returning Plugin_Handled or higher in the Pre forward.
 */

#if defined __tf2_regen_think_hook_included
#endinput
#endif
#define __tf2_regen_think_hook_included

/**
 * Called whenever the RegenThink passes the initial check and wants to actually process,
 * and after the RegenThink was rescheduled.
 * The check includes an IsPlayerAlive and a frequency check of 1 Hz.
 *
 * @param client - the player that's currently thinking
 * @return Plugin_Handled or higher to skip this think
 */
public Action TF2_OnRegenThinkPre(int client);

/**
 * Called once health regen computation based on class and attributes has finished,
 * but before the values are accumulated and applied to the player. Yes, these values
 * are float to allow for small regen values of <1 / Think Tick.
 * The left over accumulator from the previous tick is currently not exposed.
 *
 * @param client - the player that's currently thinking
 * @param regenClass - the class based health bonus for this tick
 * @param regenAttribs - the item/attib based health bonus for this tick
 * @return Plugin_Handled or higher will prevent regeneration and not change the accumulator
 */
public Action TF2_OnRegenThinkHealth(int client, float& regenClass, float& regenAttribs);

/**
 * Called once ammo and metal regen boni are computed but before they are applied.
 * The ammo regen ammount is accumulated internally, the previous value is not currently exposed.
 * 
 * @param client - the player that's currently thinking
 * @param regenAmmo - the ammount of ammo to regen 0..1 in (%)
 * @param regenMetal - the amount of metal te regen
 * @return Plugin_Handled or higher to prevent regeneration and not change the accumulator
 */
public Action TF2_OnRegenThinkAmmo(int client, float& regenAmmo, int& regenMetal);

/**
 * Called before the RegenThink hook returns with a summary of effectively changed values.
 * 
 * @param client - the player that's currently thinking
 * @param regenHealth - amount of health that was regenerated (value might ignore max health)
 * @param regenAmmo - amount of ammo regenerated (value might ignore max ammo)
 * @param regenMetal - amount of metal regenerated (value might ignore max metal)
 */
public void TF2_OnRegenThinkPost(int client, int regenHealth, float regenAmmo, int regenMetal);