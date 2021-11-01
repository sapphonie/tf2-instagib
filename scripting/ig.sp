#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>
#include <tf2>
#include <tf2items>
#pragma newdecls required

public Plugin myinfo =
{
    name        = "[tf2] instagib",
    author      = "https://sappho.io",
    description = "instagib for team fortress 2",
    version     = "0.0.1",
    url         = "https://sappho.io"
};


bool didhit[MAXPLAYERS+1];

public void OnPluginStart()
{
    // for lateloading
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
        {
            continue;
        }
        OnClientPutInServer(i);
    }

    // hook bullets fired
    AddTempEntHook("Fire Bullets", Hook_TEFireBullets);

    // for giving them new weapons
    HookEvent("post_inventory_application", eInventoryApplied);
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
}


// make every weapon (in this case our railgun) able to headshot
Action OnTraceAttack(
    int victim,
    int &attacker,
    int &inflictor,
    float &damage,
    int &damagetype,
    int &ammotype,
    int hitbox,
    int hitgroup
)
{
    didhit[attacker] = true;

    // headbox
    if (hitgroup == 1)
    {
        // always headshot if we hit the head
        damagetype |= (DMG_USE_HITLOCATIONS | DMG_CRIT);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}


Action Hook_TEFireBullets(const char[] te_name, const int[] players, int numClients, float delay)
{
    int client = TE_ReadNum("m_iPlayer") + 1;
    int userid = GetClientUserId(client);
    RequestFrame(TraceThisAttack, userid);
    return Plugin_Continue;
}

void TraceThisAttack(int userid)
{
    int client = GetClientOfUserId(userid);
    float eyepos[3];
    float aimpos[3];
    GetClientEyePosition(client, eyepos);
    // eyepos[2] -= 1.0;
    GetClientAimPosition(client, eyepos, aimpos);

    int color[4] = {255, 255, 255, 128};

    if (didhit[client])
    {
        color = {0, 255, 0, 128};
        didhit[client] = false;
    }


    TE_SetupBeamPoints(
        eyepos,
        aimpos,
        PrecacheModel("sprites/laser.vmt", true),
        PrecacheModel("sprites/laser.vmt", true),
        0,                  // startframe
        0,                  // framerate
        1.0,                // lifetime
        2.5,                // width
        0.1,                // endwidth
        1,                  // fadelength
        0.0,                // amplitude
        color,              // color
        0                   // speed
    );
    TE_SendToAll();
    return;
}

public void eInventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(userid);

    if (IsValidClient(client))
    {
        // remove those pesky real weapons
        TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
        TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
        TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
    }


    // wait a frame and add our new weapons
    RequestFrame(FrameAfterInv, userid);
}

void FrameAfterInv(int userid)
{
    int client = GetClientOfUserId(userid);

    SpawnWeapon(client, "tf_weapon_rocketlauncher", 237, _, _,
        "476 ; 0 ; "    ...     // no dmg
        "181 ; 2 ; "    ...     // no self dmg
        "4 ; 25 ; "     ...     // big clip
        "97 ; 0.1 ; "   ...     // fast reload
        "275 ; 1 ; "    ...     // no fall dmg
        "178 ; 0.5 ;"           // fast switch speed
    );

    SpawnWeapon(client, "tf_weapon_smg", 16, _, _,
        "2 ; 250 ; "    ...     // dmg bonus        = +100%
        "5 ; 8 ; "      ...     // fire rate        = -800%
        "106 ; 0 ; "    ...     // weapon spread    = perfect acc
        "266 ; 1 ; "    ...     // machina projectile penetration
        "275 ; 1 ; "    ...     // no fall dmg
        "178 ; 0.5 ;"           // fast switch speed
    );
        //"647 ; 1 ; "    ...     // tracer rounds
}

/*
    For zooming.
    Hook client M2 and zoom their FOV in and out when the hold it.
    TODO: Allow toggle zoom.
    TODO: Make zoom customizable.
*/
public Action OnPlayerRunCmd(
    int client,
    int& buttons,
    int& impulse,
    float vel[3],
    float angles[3],
    int& weapon,
    int& subtype,
    int& cmdnum,
    int& tickcount,
    int& seed,
    int mouse[2]
)
{
    if (buttons & IN_ATTACK2)
    {
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 40);
    }
    else
    {
        SetEntProp(client, Prop_Send, "m_iDefaultFOV", 90);
    }

    return Plugin_Continue;
}

int SpawnWeapon(int iClient, char[] sName, int iDefIndex, int iLevel=100, int iQual=6, char[] sAttrib="")
{
    Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION|PRESERVE_ATTRIBUTES);

    if (hWeapon == INVALID_HANDLE)
    {
        return -1;
    }

    TF2Items_SetClassname   (hWeapon, sName);
    TF2Items_SetItemIndex   (hWeapon, iDefIndex);
    TF2Items_SetLevel       (hWeapon, iLevel);
    TF2Items_SetQuality     (hWeapon, iQual);

    char sAtts[32][8];
    int iCount = ExplodeString(sAttrib, " ; ", sAtts, 32, 8);
    if (sAttrib[0] != 0 && iCount > 0)
    {
        TF2Items_SetNumAttributes(hWeapon, iCount/2);
        int i2 = 0;
        for (int i = 0; i < iCount; i+=2)
        {
            TF2Items_SetAttribute(hWeapon, i2, StringToInt(sAtts[i]), StringToFloat(sAtts[i+1]));
            i2++;
        }
        TF2Items_SetFlags(hWeapon, TF2Items_GetFlags(hWeapon) & ~PRESERVE_ATTRIBUTES);
    }
    else
    {
        TF2Items_SetFlags(hWeapon, TF2Items_GetFlags(hWeapon) & ~OVERRIDE_ATTRIBUTES);

        TF2Items_SetNumAttributes(hWeapon, 0);
    }

    if (hWeapon == INVALID_HANDLE)
    {
        return -1;
    }

    int iEntity = TF2Items_GiveNamedItem(iClient, hWeapon);
    CloseHandle(hWeapon);

    EquipPlayerWeapon(iClient, iEntity);
    return EntIndexToEntRef(iEntity);
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client))
    {
        return false;
    }

    return IsClientInGame(client);
}


bool GetClientAimPosition(int iClient, float fEyes[3], float fAim[3])
{
    float fEyesAngles[3];
    GetClientEyeAngles(iClient, fEyesAngles);
    TR_TraceRayFilter(fEyes, fEyesAngles, (CONTENTS_SOLID|CONTENTS_HITBOX), RayType_Infinite, TraceRay_OnlyHitWorld, iClient);
    if (TR_DidHit())
    {
        TR_GetEndPosition(fAim);
        return true;
    }

    return false;
}

public bool TraceRay_OnlyHitWorld(int target, int mask, int client)
{
    return (target == 0);
}
