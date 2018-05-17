/*
 * Author: Toadball - Edited from ACE_mk6mortar_fnc_handlePlayerVehicleChanged
 * Handles player getting into new vehicle.  Loads PFEG for SPH Gunner display if it is a supported SPH.
 *
 * Arguments:
 * 0: Player <OBJECT>
 * 1: New Vehicle <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [bob, sph] call itc_land_veh_sights_fnc_handlePlayerVehicleChanged;
 *
 * Public: No
 */

params ["_player", "_newVehicle"];

if (isNull _newVehicle) exitWith {};
if (!( (_newVehicle isKindOf "B_MBT_01_arty_base_F") || (_newVehicle isKindOf "B_MBT_02_arty_base_F") )) exitWith {};

[{
    params ["_args", "_pfID"];
    _args params ["_mortarVeh", "_fireModes"];

    if ((vehicle ACE_player) != _mortarVeh) then {
        [_pfID] call CBA_fnc_removePerFrameHandler;
    } else {



        private _display = uiNamespace getVariable ["ACE_Mk6_RscWeaponRangeArtillery", displayNull];
        if (isNull _display) exitWith {}; //It may be null for the first frame

        private _chargeText = format ["<t size='0.8'>%1: %2 <img image='%3'/></t>", (localize LSTRING(rangetable_charge)), _currentChargeMode, QPATHTOF(UI\ui_charges.paa)];

        //Hud should hidden in 3rd person
        private _notGunnerView = cameraView != "GUNNER";

        //Calc real azimuth/elevation
        //(looking at the sky VS looking at ground will radicaly change fire direction because BIS)
        private _realAzimuth = -1;
        private _realElevation = -1;

        private _useRealWeaponDir = (ctrlText (_display displayCtrl 173)) == "--";
        if (_useRealWeaponDir && {(_mortarVeh ammo (currentWeapon _mortarVeh)) == 0}) then {
            // With no ammo, distance display will be empty, but gun will still fire at wonky angle if aimed at ground
            private _testSeekerPosASL = AGLtoASL (positionCameraToWorld [0,0,0]);
            private _testSeekerDir = _testSeekerPosASL vectorFromTo (AGLtoASL (positionCameraToWorld [0,0,1]));
            private _testPoint = _testSeekerPosASL vectorAdd (_testSeekerDir vectorMultiply viewDistance);
            if ((terrainIntersectASL [_testSeekerPosASL, _testPoint]) || {lineIntersects [_testSeekerPosASL, _testPoint]}) then {
                _useRealWeaponDir = false; // If we are not looking at infinity (based on viewDistance)
            };
        };

        if (_useRealWeaponDir) then {
            //No range (looking at sky), it will follow weaponDir:
            private _weaponDir = _mortarVeh weaponDirection (currentWeapon _mortarVeh);
            _realAzimuth = (_weaponDir select 0) atan2 (_weaponDir select 1);
            _realElevation = asin (_weaponDir select 2);
        } else {
            //Valid range, will fire at camera dir
            private _lookVector = ((positionCameraToWorld [0,0,0]) call EFUNC(common,positionToASL)) vectorFromTo ((positionCameraToWorld [0,0,10]) call EFUNC(common,positionToASL));
            _realAzimuth = ((_lookVector select 0) atan2 (_lookVector select 1));
            private _upVectorDir = (((vectorUp _mortarVeh) select 0) atan2 ((vectorUp _mortarVeh) select 1));
            private _elevationDiff = (cos (_realAzimuth - _upVectorDir)) * acos ((vectorUp _mortarVeh) select 2);
            _realElevation = ((180 / PI) * (_mortarVeh animationPhase "mainGun")) + 75 - _elevationDiff;
        };

        //Update Heading Display:
        if (_notGunnerView || (!GVAR(allowCompass))) then {
            (_display displayCtrl 80156) ctrlSetText "";
        } else {
            if (_useMils) then {
                (_display displayCtrl 80156) ctrlSetText str (((round (_realAzimuth * 6400 / 360)) + 6400) % 6400);
            } else {
                (_display displayCtrl 80156) ctrlSetText str ((round (_realAzimuth + 360)) % 360);
            };
        };

        //Update CurrentElevation Display and "charge" text
        if (_notGunnerView) then {
            (_display displayCtrl 80085) ctrlSetStructuredText parseText "";
            (_display displayCtrl 80175) ctrlSetText "";
        } else {
            (_display displayCtrl 80085) ctrlSetStructuredText parseText _chargeText;

            if (_useMils) then {
                (_display displayCtrl 80175) ctrlSetText str ((round (_realElevation * 6400 / 360)) % 6400);
            } else {
                (_display displayCtrl 80175) ctrlSetText str (((round (_realElevation * 100)) / 100) % 360);
            };
        };

        //Update ElevationNeeded Display:
        if (_notGunnerView || (!GVAR(allowComputerRangefinder))) then {
            (_display displayCtrl 80176) ctrlSetText "";
        } else {
            private _elevDeg = parseNumber ctrlText (_display displayCtrl 176);
            if (_elevDeg <= 0) then { //Bad data means "----" out of range
                (_display displayCtrl 80176) ctrlSetText (ctrlText (_display displayCtrl 176));
            } else {
                _elevDeg = _elevDeg + (_realElevation - (parseNumber ctrlText (_display displayCtrl 175)));
                if (_useMils) then {
                    (_display displayCtrl 80176) ctrlSetText str round ((round (_elevDeg * 6400 / 360)) % 6400);
                } else {
                    (_display displayCtrl 80176) ctrlSetText str (((round (_elevDeg * 100)) / 100) % 360);
                };
            };
        };
    };
}, 0, [_newVehicle]] call CBA_fnc_addPerFrameHandler;
