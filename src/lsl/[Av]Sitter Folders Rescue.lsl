/*
    Copyright (C) 2025  MdONeil 
    secondlife:///app/agent/ae929a12-297c-45be-9748-562ee17e937e/about

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

string LSD_PROJECT = "💥😼😖";
list gl_nc_names = ["AVpos"];
integer gi_nc_index;
string gs_nc_name;
string gs_folder_name;
string gs_sub_name;
key request;
string gs_scr;

string next_nc() {
    integer nc_index = gi_nc_index;
    integer nc_len = llGetListLength(gl_nc_names);
    for (;nc_index < nc_len; ++nc_index) {
        string nc_name = llList2String(gl_nc_names, nc_index);
        if (llGetInventoryType(nc_name) == INVENTORY_NOTECARD) {
            return nc_name;
        }
    }
    return "";
}

clear() {
    llLinksetDataDeleteFound("^" + LSD_PROJECT, "");
    llRemoveInventory(llGetScriptName());
}


default {
    state_entry() {
        gs_folder_name = llGetObjectName();
        gs_scr = llGetScriptName();

        gs_nc_name = next_nc();
        if (gs_nc_name != "") {
            llOwnerSay("Processing \"" + gs_nc_name + "\" for data recovery.");
            request = llGetNumberOfNotecardLines(gs_nc_name);
        }
        else {
            llOwnerSay("No AvSitter notecard data found.");
            clear();
        }

        llLinksetDataDeleteFound("^" + LSD_PROJECT, "");
    }

    listen( integer channel, string name, key id, string message ) {
        if (message == "Rescue") {
            integer datas_len = llLinksetDataCountFound("^" + LSD_PROJECT);
            integer data_index;
            string dest = gs_scr + "|" + gs_folder_name;

            for (; data_index < datas_len; ++data_index) {
                string skey = llList2String(llLinksetDataFindKeys("^" + LSD_PROJECT, data_index, 1), 0);
                list datas = llParseString2List(llLinksetDataRead(skey), ["|"], []);
                
                if (datas != []) {
                    list dest_data = llParseString2List(llReplaceSubString(skey, LSD_PROJECT, "", 0), ["|"], []); 
                    string path = dest + "|" + llList2String(dest_data, 0);

                    if (llGetAgentSize(id) == ZERO_VECTOR) { clear(); return; }
                    integer result = llGiveAgentInventory(id, llList2String(dest_data, 1), datas, [TRANSFER_DEST, path]);

                    string msg;
                    if (result == TRANSFER_BAD_OPTS) msg = "A bad option was passed in the options list.";
                    else if (result == TRANSFER_THROTTLE) msg = "Transfer rate exceeded the inventory transfer throttle.";
                    else if (result == TRANSFER_BAD_ROOT) msg = "The root path specified in TRANSFER_DEST contained an invalid directory or was reduced to nothing.";

                    if (msg != "") llOwnerSay(msg);
                }
            }
        }
        
        llOwnerSay(gs_scr +": Completed folder rescue for: " + gs_folder_name);
        clear();
    }

    dataserver(key queryid, string data) {
        if (queryid != request) return;
        integer line_num = (integer)data;
        if (line_num < 1) return;

        integer line_index;
        for (; line_index < line_num; ++line_index) {
            string line = llGetNotecardLineSync(gs_nc_name, line_index);
            if (line == EOF || line == NAK) jump continue_processing;
            
            line = llStringTrim(llGetSubString(line, llSubStringIndex(line, "◆") + 1, -1), STRING_TRIM_HEAD);
            string command = llList2String(llParseString2List(line, [" "], []), 0);
            list parts = llParseStringKeepNulls(llGetSubString(line, llSubStringIndex(line, " ") + 1, -1), 
                [" | ", " |", "| ", "|"], []);
            string part0 = llStringTrim(llList2String(parts, 0), STRING_TRIM);
            
            if (command == "MENU") {
                gs_sub_name = part0;
            }
            else if (command == "POSE" || command == "SYNC") {
                integer part_index;
                integer parts_len = llGetListLength(parts);
                list rescued;
                
                for (; part_index < parts_len; ++part_index) {
                    string item = llList2String(parts, part_index);
                    if (~llGetInventoryType(item)) {
                        if ((llGetInventoryPermMask(item, MASK_OWNER) & PERM_COPY) == 0) {
                            llOwnerSay("The inventory item \"" + item + "\" lacks copy permissions and would break the furniture if removed.");
                        }
                        else rescued += item;                        
                    }
                }

                string skey = LSD_PROJECT + gs_sub_name + "|" + part0;
                string pre_rescued = llLinksetDataRead(skey);
                if (pre_rescued != "") {
                    list pre = llParseString2List(pre_rescued, ["|"], []);
                    integer pre_index;
                    integer pre_len = llGetListLength(rescued);
                    for (;pre_index < pre_len; ++pre_index) {
                        string item = llList2String(pre, pre_index);
                        if (llListFindList(rescued, (list)item) < 0) rescued += item;
                    }
                }
                llLinksetDataWrite(skey, llDumpList2String(rescued, "|"));
            }
        }
        @continue_processing;

        ++gi_nc_index;
        gs_nc_name = next_nc();
        if (gs_nc_name != "") {
            llOwnerSay("Processing \"" + gs_nc_name + "\" for data recovery.");
            request = llGetNumberOfNotecardLines(gs_nc_name);
        }
        else {
            integer datas_len = llLinksetDataCountFound("^" + LSD_PROJECT);
            llOwnerSay(gs_scr +": " + (string)datas_len + " Folder find.");

            float time = datas_len * 0.05; // 3 seconds per folder = 0.05 minutes
            string text = gs_scr + "\n" + (string)datas_len + " folders found." +
                         "\nPress \"Rescue\" to begin recovery." +
                         "\nEstimated time: " + (string)time + " minutes";

            string owner = llGetOwner();
            llDialog(owner, text, ["Rescue", "Cancel"], 3456);
            llListen(3456, llKey2Name(owner), owner, "");
        }
    }
}

