#!/usr/bin/python
# encoding: utf-8

'''
TODO: add description
TODO: use the os path bundle instead of regular expressions
TODO: maybe add vim runtime info (and other general info) to top of the menu, with a separator (&runtimepath)
'''

import os, re

scripts = {}
menus = []

is_source_line = lambda x: re.match("^.*Last set from", x)
sanitise_menu = lambda x: x.replace(" ", "\\ ").replace(".", "\\.").replace("|", "\\|")

DEFAULT_SPILLOVER = "*."
TRUNC_LIMIT = 20

def init_script(path):
    name = os.path.splitext(os.path.basename(path))[0]
    scripts[path] = {"name": name, "commands": [], "mappings": [], "abbreviations": [], "functions": [], "autocmds": []}

    return scripts[path]

def get_spillover(name):
    # TODO: make sure that vim.vim plugins show up here (seems to load erratically)
    # for some reason, vimrc pattern matching fails with $ at the end
    patterns = {r"^g?vimrc": "vim.", r"^\d": "0-9.", r"^[a-i]": "a-i.", r"^[j-r]": "j-r.", r"^[s-z]": "s-z."}

    for pattern in patterns.keys():
        if re.match(pattern, name.strip(), re.IGNORECASE):
            return patterns.get(pattern)

    return DEFAULT_SPILLOVER

def gen_menu(root, spillover, threshhold):
    head = "amenu " + root + "."

    for path, properties in scripts.items():
        name = sanitise_menu(properties["name"])

        if int(spillover) and len(scripts.keys()) > int(threshhold):
            menu_prefix = head + get_spillover(name) + name + "."
        else:
            menu_prefix = head + name + "."

        gen_commands_menu(menu_prefix, properties["commands"])
        gen_files_menu(menu_prefix, path)
        gen_mappings_menu(menu_prefix, properties["mappings"])
        gen_autocmds_menu(menu_prefix, properties["autocmds"])
        gen_help_menu(menu_prefix, name)

    menus.sort()

    return menus

# add commands
def gen_commands_menu(menu_prefix, commands):
    for command in commands:
        command_name = sanitise_menu(command.keys()[0]).replace("\\ ", " ")      # unescape spaces in commands
        command_label = sanitise_menu(command[command.keys()[0]])
        command_item = menu_prefix + "Commands." + command_name + "<Tab>:" + command_label + " :" + command_name + "<cr>"
        menus.append(command_item)

# add files
def gen_files_menu(menu_prefix, path):
    file_path = sanitise_menu(path)
    dir_path = sanitise_menu(os.path.dirname(path))
    trunc_file_path = "<" + file_path[-TRUNC_LIMIT:]

    # TODO: test these again (some paths aren't being explored)
    # TODO: fix this so that it opens the path in Finder, or whatever app based on the platform
    path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ system\ browser<Tab>:!open\ " + dir_path + " :!open " + dir_path + "<cr>"
    menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ horizontal\ split<Tab>:Explore\ " + dir_path + " :Explore " + dir_path + "<cr>"
    #menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ vertical\ split<Tab>:Explore!\ " + dir_path + " :Explore! " + dir_path + "<cr>"
    #menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ horizontal\ split<Tab>:Sexplore\ " + dir_path + " :Sexplore " + dir_path + "<cr>"
    menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ vertical\ split<Tab>:Sexplore!\ " + dir_path + " :Sexplore! " + dir_path + "<cr>"
    menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ belowright<Tab>:Hexplore\ " + dir_path + " :Hexplore " + dir_path + "<cr>"
    #menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ aboveleft<Tab>:Hexplore!\ " + dir_path + " :Hexplore! " + dir_path + "<cr>"
    #menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ leftabove<Tab>:Vexplore\ " + dir_path + " :Vexplore " + dir_path + "<cr>"
    #menus.append(path_item)

    #path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ rightbelow<Tab>:Vexplore!\ " + dir_path + " :Vexplore! " + dir_path + "<cr>"
    #menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ new\ tab<Tab>:Texplore\ " + dir_path + " :Texplore " + dir_path + "<cr>"
    menus.append(path_item)

    # TODO: check if NERDTree exists first
    # vim: echo(loaded_nerd_tree) -- 1 if loaded
    path_item = menu_prefix + "Files." + trunc_file_path + ".Explore\ in\ NERDTREE<Tab>:NERDTreeFind\ " + dir_path + " :NERDTree " + dir_path + "<cr>"
    menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Edit\ here<Tab>:edit\ " + file_path + " :edit " + file_path + "<cr>"
    menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Edit\ in\ horizontal\ split<Tab>:split\ " + file_path + " :split " + file_path + "<cr>"
    menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Edit\ in\ vertical\ split<Tab>:vsplit\ " + file_path + " :vsplit " + file_path + "<cr>"
    menus.append(path_item)

    path_item = menu_prefix + "Files." + trunc_file_path + ".Edit\ in\ new\ tab<Tab>:tabnew\ " + file_path + " :tabnew " + file_path + "<cr>"
    menus.append(path_item)

# add mappings
def gen_mappings_menu(menu_prefix, mappings):
    for mode, keys, command in mappings:
        mode = sanitise_menu(mode)
        keys = sanitise_menu(keys)
        command = sanitise_menu(command)

        mapping_item = menu_prefix + "Mappings." + mode + "." + keys + "<Tab>" + command + " :" + "<cr>"

        menus.append(mapping_item)

# add autocmds
def gen_autocmds_menu(menu_prefix, autocmds):
    for buffer, group, event, pattern, autocmd in autocmds:
        autocmd = trunc_autocmd = sanitise_menu(autocmd)

        if (len(autocmd) > TRUNC_LIMIT):
            trunc_autocmd = autocmd[:TRUNC_LIMIT] + ">"

        autocmd_item = menu_prefix + "Autocmds."

        if buffer:
            autocmd_item += sanitise_menu(buffer) + "."

        if group:
            autocmd_item += sanitise_menu(group) + "."

        autocmd_item += sanitise_menu(event) + "."

        if pattern:
            autocmd_item += sanitise_menu(pattern) + "."

        autocmd_item += trunc_autocmd + "<Tab>" + autocmd + " :" + "<cr>"

        menus.append(autocmd_item)

# add help
def gen_help_menu(menu_prefix, name):
    path_item = menu_prefix + "Help" + " :helpgrep " + name + "<cr>"
    menus.append(path_item)

def get_source_script(line):
    source_path = re.findall(r"^.*Last set from (.+$)", line)[0]
    source_path = sanitise_path(source_path)

    # TODO: this condition shouldn't occur
    #script = scripts.get(source_path, init_script(source_path))
    if source_path in scripts:
        return scripts.get(source_path)
    else:
        #print("############# no existing script found for this source!")
        return init_script(source_path)

def sanitise_path(path):
    # TODO: test if this is actually necessary
    path = re.sub(r"^~", os.getenv("HOME"), path)

    path = os.path.normpath(path)
    path = os.path.normcase(path)
    path = os.path.realpath(path)
    path = os.path.abspath(path)

    return path

def parse_scriptnames(scriptnames):
    for path in scriptnames:
        path = re.sub(r"^\s*\d+:\s+", "", path)     # strip out leading indexes
        path = sanitise_path(path)

        init_script(path)

# TODO: consider that some commands are local to the buffer, see how you'd handle reloading
def parse_commands(commands):
    for i, command in enumerate(commands[1:]):
        command = command.strip()

        # begin with command lines
        if not is_source_line(command):
            pattern = r'''
            ^
            ([!"b]\s+)?                 # attribute
            (\w+\s+)                    # name
            ([01+?*]\s+)?               # args
            ((\.|1c|%|0c)\s+)?          # range
            ((dir|file|buffer)\s+)?     # complete
            :?                          # potential colon
            ([a-z].+)                   # definition/label
            $
            '''

            matches = re.findall(pattern, command, re.VERBOSE | re.IGNORECASE)

            try:
                attribute, name, args, range, complete, label = \
                    matches[0][0].strip(), \
                    matches[0][1].strip(), \
                    matches[0][2].strip(), \
                    matches[0][3].strip(), \
                    matches[0][5].strip(), \
                    matches[0][7].strip()
                #print(attribute, name, args, range, complete, definition)

            except (IndexError):
                #print("%%% parse error: '" + command + "'")
                pass

            try:
                # get the source script from the next list item
                # '2' because we skipped the header list item
                source_script = get_source_script(commands[i+2])

                source_script["commands"].append({name: label})

            except (IndexError):
                pass

def parse_mappings(mappings):
    for i, mapping in enumerate(mappings):
        #print("**************** %s" % mapping)
        # begin with mapping lines
        if not is_source_line(mapping):
            # mode, mapping, command
            pattern = r'''
            ^
            ([nvsxo!ilc]+)?    # mode
            \s+
            ([\S]+)            # keys
            \s+
            ([*&@]+)?          # attribute
            \s*
            (.+)               # command
            $
            '''

            matches = re.findall(pattern, mapping, re.VERBOSE | re.IGNORECASE)

            try:
                # TODO: consider doing something with the attribute
                # TODO: this whole thing is complicated because there can be more than
                # one mode for the same mapping.
                # TODO: if there is more than one mode, split it up into an array
                # and duplicate the mappings (maybe). it's a bit repetitive. but it
                # would allow you to use mode names instead of just codes.
                # TODO: the mapping with more than one mode (SearchComplete /) is coming through
                # with a space for a mode instead. not good. no foreseeable way around this. issue.
                mode, keys, attribute, command = \
                    matches[0][0].strip(), \
                    matches[0][1].strip(), \
                    matches[0][2].strip(), \
                    matches[0][3].strip()

                # restore blank mode to original value (space)
                if mode is "":
                    mode = " "

                # delete anything preceding the first :
                # TODO: test that this works
                command = re.sub("^.*:", ":", command)

                # cater for multiple modes
                modes = list(mode)

                mode_map = {
                        " ": "Normal, Visual, Select and Operator-pending",
                        "n": "Normal",
                        "v": "Visual and Select",
                        "s": "Select",
                        "x": "Visual",
                        "o": "Operator-pending",
                        "!": "Insert and Command-line",
                        "i": "Insert",
                        "l": ":lmap",
                        "c": "Command-line"
                }

                modes = [m + " - " + mode_map.get(m) for m in modes]

            except (IndexError):
                #print("%%% parse error: '" + command + "'")
                pass

            try:
                # get the source script from the next list item
                source_script = get_source_script(mappings[i+1])

                #if (len(modes) > 1):
                    #print("######## ", modes, keys, command)

                for m in modes:
                    source_script["mappings"].append([m, keys, command])

            except (IndexError, TypeError):
                pass

# TODO: improve this algorithm
def parse_autocmds(autocmds):
    # delete the listing header
    autocmds = autocmds[1:]

    # group/event lines have no leading spaces
    is_event_line = lambda x: not re.match("^\s", x)
    is_buffer_line = lambda x: re.match("^\s*__", x)

    pos = 0
    for i in enumerate(autocmds):
        if pos > i:
            continue

        # start with group/event lines
        if is_event_line(autocmds[pos]):
            group = None

            try:
                group, event = autocmds[pos].strip().split()
            except:
                event = autocmds[pos]

            pos += 1
            while pos < len(autocmds):
                if is_event_line(autocmds[pos]):
                    # we're done with this group/event, continue through
                    break
                else:
                    buffer = None
                    group = None

                    if is_buffer_line(autocmds[pos]):
                        buffer = autocmds[pos].strip()
                        pos =+ 1      # move to the next line

                    # the next line may be the source
                    if is_source_line(autocmds[pos+1]):
                        # try to get the pattern (after the first 4 leading spaces)
                        # if no pattern exists, default to pattern from previous autocmd
                        try:
                            pattern, autocmd = re.findall("^\s{4}([^\s]+)\s+(.+)$", autocmds[pos])[0]
                            pattern = pattern.strip()
                        except IndexError:
                            #pattern = None
                            autocmd = autocmds[pos]

                        source = autocmds[pos+1]
                        pos += 2
                    # or the line after that
                    else:
                        pattern = autocmds[pos].strip()
                        autocmd = autocmds[pos+1]
                        source = autocmds[pos+2]
                        pos += 3

                    try:
                        # get the source script from the next list item
                        source_script = get_source_script(source)
                        source_script["autocmds"].append([buffer, group, event.strip(), pattern, autocmd.strip()])

                    except (IndexError):
                        pass

def get_menu_commands(menu_root, spillover, threshhold, scriptnames, commands, mappings, autocmds):
    print(mappings)
    parse_scriptnames(scriptnames.strip().split("\n"))
    parse_commands(commands.strip().split("\n"))
    parse_mappings(mappings.strip().split("\n"))
    #parse_autocmds(autocmds.strip().split("\n"))

    return gen_menu(menu_root, spillover, threshhold)

